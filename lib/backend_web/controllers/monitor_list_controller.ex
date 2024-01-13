defmodule BackendWeb.MonitorListController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  alias BackendWeb.API.Schemas.MonitorListResponse

  require Logger

  operation :get,
    summary: "Get a list of monitors for your account",
    tags: ["Monitors"],
    responses: [
      ok: {"List of monitors", "application/json", MonitorListResponse}
    ]

  @doc """
  Return errors of one or more monitors.
  """
  def get(conn, _params) do
    account_id = get_session(conn, :account_id)

    monitor_list =
      account_id
      |> Backend.Projections.list_monitors()
      |> Enum.map(fn m -> %{name: m.name, logical_name: m.logical_name} end)

    Backend.Projections.register_api_hit(account_id)
    json(conn, monitor_list)
  end
end
