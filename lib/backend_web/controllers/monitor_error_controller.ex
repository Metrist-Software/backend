defmodule BackendWeb.MonitorErrorController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  require Logger
  alias Backend.Projections.Dbpa.MonitorError
  alias BackendWeb.ApiHelpers
  alias BackendWeb.API.CommonParameters
  alias BackendWeb.API.Schemas.MonitorErrorsResponse

  @limit_opts [default: 100, maximum: 500]
  @default_limit_str "100"

  operation :get,
    summary: "Get monitor errors for one or more monitors",
    parameters:
      []
      |> CommonParameters.from([required: true])
      |> CommonParameters.to([required: true])
      |> CommonParameters.cursor_after
      |> CommonParameters.cursor_before
      |> CommonParameters.limit
      |> CommonParameters.only_shared
      |> CommonParameters.checks
      |> CommonParameters.instances
      |> CommonParameters.monitors,
    tags: ["Monitors"],
    responses: [
      ok: {"List of monitor errors", "application/json", MonitorErrorsResponse}
    ]

  @doc """
  Return errors of one or more monitors.
  """
  def get(conn, params) do
    account_id = get_session(conn, :account_id)
    monitors = params["m"]
    only_shared? = params["only_shared"] == "true"
    cursor_after = params["cursor_after"]
    cursor_before = params["cursor_before"]

    checks = params["c"]
    instances = params["i"]

    limit =
      Map.get(params, "limit", @default_limit_str)
      |> String.to_integer()
      |> min(@limit_opts[:maximum])

    {from, to} = ApiHelpers.get_daterange_from_params(params)

    account_id = if only_shared? do
     "SHARED"
    else
      account_id
    end

    result = MonitorError.count_per_mci(account_id, monitors, from, to,
        limit: limit,
        cursor_after: cursor_after,
        cursor_before: cursor_before,
        checks: checks,
        instances: instances
      )

    entries = Enum.map(result.entries, fn s ->
        %{
          timestamp: ApiHelpers.naive_to_utc_dt(s.time),
          monitor_logical_name: s.monitor_logical_name,
          instance: s.instance_name,
          check: s.check_logical_name,
          count: s.count
        }
      end)

    Backend.Projections.register_api_hit(account_id)

    json(conn, %{
      entries: entries,
      metadata: BackendWeb.API.PaginationHelpers.metadata_json(result.metadata)
    })
  end
end
