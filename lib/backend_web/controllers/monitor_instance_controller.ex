defmodule BackendWeb.MonitorInstanceController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  alias BackendWeb.API.Schemas.MonitorInstancesResponse
  alias BackendWeb.API.CommonParameters

  require Logger

  operation :get,
    summary: "Given a list of monitors, return a monitor + instances for each requested monitors, optionally including SHARED data",
    parameters:
      []
      |> CommonParameters.include_shared
      |> CommonParameters.monitors,
    tags: ["Monitors"],
    responses: [
      ok: {"List of instances by monitor", "application/json", MonitorInstancesResponse}
    ]

  @doc """
  Return a monitor + instances for each requested monitors, optionally including SHARED data
  """
  def get(conn, params) do
    account_id = get_session(conn, :account_id)
    monitors = params["m"]

    include_shared? = params["include_shared"] == "true"

    accounts_results = Backend.Projections.get_instances_for_monitors(account_id, monitors)
    result =
      if include_shared? do
        shared_results = Backend.Projections.get_instances_for_monitors("SHARED", monitors)
        Map.merge(accounts_results, shared_results, fn _key, checks1, checks2 ->
          Enum.uniq(checks1 ++ checks2)
        end)
      else
        accounts_results
      end

    Backend.Projections.register_api_hit(account_id)

    json(conn, Enum.map(result, fn {monitor_logical_name, instances} ->
      %{
        monitor_logical_name: monitor_logical_name,
        instances: Enum.map(instances, &(&1.instance_name))
      }
    end))
  end
end
