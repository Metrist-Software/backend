defmodule BackendWeb.MonitorTelemetryController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  require Logger
  alias BackendWeb.ApiHelpers
  alias BackendWeb.API.CommonParameters
  alias BackendWeb.API.Schemas.MonitorTelemetryResponse

  @doc """
  Return telemetry of one or more monitors.
  """


  operation :get,
    summary: "Return telemetry for one or more monitors. Limit to 1000 results.",
    parameters:
      []
      |> CommonParameters.from([required: true])
      |> CommonParameters.to([required: true])
      |> CommonParameters.include_shared
      |> CommonParameters.checks
      |> CommonParameters.instances
      |> CommonParameters.monitors,
    tags: ["Monitors"],
    responses: [
      ok: {"List of monitor telemetry", "application/json", MonitorTelemetryResponse}
    ]

  @doc """
  Return telemetry for one or more monitors.
  """
  def get(conn, params) do
    account_id = get_session(conn, :account_id)
    monitors = params["m"]
    checks = params["c"]
    instances = params["i"]
    include_shared = params["include_shared"] == "true"
    {from, to} = ApiHelpers.get_daterange_from_params(params)
    monitor_telemetry =
      Backend.Telemetry.average_per_mci(from, to, monitors, account_id, limit: 1000, include_shared: include_shared, checks: checks, instances: instances)
      |> Enum.map(fn s ->
        %{
          timestamp: ApiHelpers.naive_to_utc_dt(s.time),
          monitor_logical_name: s.monitor_id,
          instance: s.instance_id,
          check: s.check_id,
          value: s.value
        }
      end)

    Backend.Projections.register_api_hit(account_id)
    json(conn, monitor_telemetry)
  end
end
