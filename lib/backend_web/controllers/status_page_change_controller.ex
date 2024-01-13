defmodule BackendWeb.StatusPageChangeController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  require Logger
  alias Backend.Projections.Dbpa.StatusPage
  alias BackendWeb.ApiHelpers
  alias BackendWeb.API.CommonParameters
  alias BackendWeb.API.Schemas.StatusPageChangesResponse

  @limit_opts [default: 100, maximum: 500]
  @default_limit_str "100"

  operation :get,
    summary: "Return list of status pages changes for one or more monitors.",
    parameters:
      []
      |> CommonParameters.from([required: true])
      |> CommonParameters.to
      |> CommonParameters.cursor_after
      |> CommonParameters.cursor_before
      |> CommonParameters.limit
      |> CommonParameters.monitors,
    tags: ["Monitors"],
    responses: [
      ok: {"List of status page changes", "application/json", StatusPageChangesResponse}
    ]

  @default_limit_str "500"
  @doc """
  Return status page changes for one or more monitors.
  """
  def get(conn, params) do
    account_id = get_session(conn, :account_id)
    cursor_after = params["cursor_after"]
    cursor_before = params["cursor_before"]
    monitors = params["m"]
    {from, to} = ApiHelpers.get_daterange_from_params(params)

    limit =
      Map.get(params, "limit", @default_limit_str)
      |> String.to_integer()
      |> min(@limit_opts[:maximum])

    result =
      StatusPage.raw_status_page_changes("SHARED", monitors, from, to,
        limit: limit,
        cursor_after: cursor_after,
        cursor_before: cursor_before
      )

    entries = Enum.map(result.entries, fn s ->
        %{
          id: s.id,
          timestamp: ApiHelpers.naive_to_utc_dt(s.changed_at),
          monitor_logical_name: s.status_page_name,
          component: s.component_name,
          status: s.status
        }
      end)

    Backend.Projections.register_api_hit(account_id)

    json(conn, %{
      entries: entries,
      metadata: BackendWeb.API.PaginationHelpers.metadata_json(result.metadata)
    })
  end
end
