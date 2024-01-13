defmodule BackendWeb.MonitorStatusController do
  alias BackendWeb.ApiHelpers
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  alias BackendWeb.API.CommonParameters
  alias BackendWeb.API.Schemas.MonitorStatusResponse


  require Logger

  @doc """
  Return the status of one or more monitors.

  Parameters:

  * `m[]` - one or more monitors to get the status for. These should be the logical
            names for the monitors.

  Returns an array of JSON objects containing logical name, last check date and status for
  each monitor that could be found (invalid logical names simply will not return a corresponding
  object).

  Example:

  ```
  curl -H "Authorization: Bearer XXX" 'https://app.metrist.io/api/v0/monitor-status?m[]=testsignal'
  ```

  Returns:

  ```
  [
    {
      "monitor_logical_name": "testsignal",
      "last_checked": "2022-04-21T14:58:17.175203",
      "state": "up"
    }
  ]
  ```
  """

  operation :get,
    summary: "Returns monitor status for one or more monitors",
    parameters:
      CommonParameters.monitors,
    tags: ["Monitors"],
    responses: [
      ok: {"List of monitors with their statuses", "application/json", MonitorStatusResponse}
    ]

  def get(conn, params) do
    account_id = get_session(conn, :account_id)

    monitors = params["m"]
    monitor_states =
      monitors
      |> Enum.map(&Backend.RealTimeAnalytics.get_snapshot_or_nil(account_id, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn s ->
        %{
          monitor_logical_name: s.monitor_id,
          last_checked: ApiHelpers.naive_to_utc_dt(s.last_checked),
          state: s.state
        }
      end)

    Backend.Projections.register_api_hit(account_id)
    json(conn, monitor_states)
  end
end
