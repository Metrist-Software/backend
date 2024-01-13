defmodule BackendWeb.MonitorCheckController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  alias BackendWeb.API.Schemas.MonitorChecksResponse
  alias BackendWeb.API.CommonParameters

  require Logger

  operation :get,
    summary: "Given a list of monitors, return a monitor + checks for each requested monitors, optionally including SHARED data",
    parameters:
      []
      |> CommonParameters.include_shared
      |> CommonParameters.monitors,
    tags: ["Monitors"],
    responses: [
      ok: {"List of checks by monitor", "application/json", MonitorChecksResponse}
    ]

  @doc """
  Return a monitor + checks for each requested monitors, optionally including SHARED data
  """
  def get(conn, params) do
    account_id = get_session(conn, :account_id)
    monitors = params["m"]

    include_shared? = params["include_shared"] == "true"

    accounts_results = Backend.Projections.get_checks_for_monitors(account_id, monitors)
    result =
      if include_shared? do
        shared_results = Backend.Projections.get_checks_for_monitors("SHARED", monitors)
        Map.merge(accounts_results, shared_results, fn _key, checks1, checks2 ->
          Enum.uniq_by(checks1 ++ checks2, fn check -> check.logical_name end)
        end)
      else
        accounts_results
      end

    Backend.Projections.register_api_hit(account_id)

    json(conn, Enum.map(result, fn {monitor_logical_name, checks} ->
      %{
        monitor_logical_name: monitor_logical_name,
        checks: Enum.map(checks, fn check ->
          %{
            logical_name: check.logical_name,
            name: check.name
          }
        end)
      }
    end))
  end
end
