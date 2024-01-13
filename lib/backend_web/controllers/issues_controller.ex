defmodule BackendWeb.IssueController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  alias BackendWeb.API.PaginationHelpers
  alias BackendWeb.API.Schemas.{IssuesListResponse, IssuesList, IssueEventsListResponse}
  alias BackendWeb.API.CommonParameters
  alias BackendWeb.ApiHelpers

  operation :list_issues,
    summary: "List of issues",
    parameters:
      []
      |> CommonParameters.from()
      |> CommonParameters.to()
      |> CommonParameters.cursor_after()
      |> CommonParameters.cursor_before()
      |> CommonParameters.limit()
      |> Keyword.merge(
        service: [in: :query, type: :string, description: "Service name", required: false],
        severity: [
          in: :query,
          description: "Severity",
          schema: %OpenApiSpex.Schema{type: :string, enum: IssuesList.severity()}
        ],
        source: [
          in: :query,
          description: "Source of the event",
          schema: %OpenApiSpex.Schema{type: :string, enum: IssuesList.source()}
        ]
      ),
    tags: ["Issues"],
    responses: [
      ok: {"List of issues", "application/json", IssuesListResponse}
    ]

  def list_issues(conn, params) do
    account_id = get_session(conn, :account_id)
    {from, to} = ApiHelpers.get_daterange_from_params(params)

    with :ok <- ApiHelpers.validate_timerange(from, to) do
      page_params =
        Map.drop(params, [:from, :to, :severity])
        |> Map.merge(%{
          start_time_after: from,
          start_time_before: to,
          worst_state: params[:severity]
        })

      result = Backend.Projections.list_issues_paginated(account_id, page_params)

      entries =
        Enum.map(result.entries, fn %Backend.Projections.Dbpa.Issue{} = e ->
          %{
            id: e.id,
            service: e.service,
            start_time: e.start_time,
            end_time: e.end_time,
            severity: e.worst_state,
            sources: e.sources
          }
        end)

      json(conn, %{
        entries: entries,
        metadata: PaginationHelpers.metadata_json(result.metadata)
      })
    else
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(ApiHelpers.generate_error(reason, "Invalid request"))
    end
  end

  operation :list_issue_events,
    summary: "List of issue events",
    parameters:
      []
      |> CommonParameters.from()
      |> CommonParameters.to()
      |> CommonParameters.cursor_after()
      |> CommonParameters.cursor_before()
      |> CommonParameters.limit()
      |> Keyword.merge(
        issue_id: [
          in: :path,
          type: :string,
          description: "Issue id",
          required: true
        ],
        state: [
          in: :query,
          description: "State",
          schema: %OpenApiSpex.Schema{type: :string, enum: IssuesList.severity()}
        ],
        source: [
          in: :query,
          description: "Source of the event",
          schema: %OpenApiSpex.Schema{type: :string, enum: IssuesList.source()}
        ]
      ),
    tags: ["Issues"],
    responses: [
      ok: {"List of issue events", "application/json", IssueEventsListResponse}
    ]

  def list_issue_events(conn, params) do
    account_id = get_session(conn, :account_id)
    {from, to} = ApiHelpers.get_daterange_from_params(params)

    with :ok <- ApiHelpers.validate_timerange(from, to) do
      page_params =
        Map.drop(params, [:from, :to])
        |> Map.merge(%{
          start_time_after: from,
          start_time_before: to
        })

      result = Backend.Projections.list_issue_events_paginated(account_id, page_params)

      entries =
        Enum.map(result.entries, fn %Backend.Projections.Dbpa.IssueEvent{} = e ->
          %{
            id: e.id,
            source: e.source,
            component_id: e.component_id,
            region: e.region,
            check_logical_name: e.check_logical_name,
            state: e.state,
            start_time: e.start_time
          }
        end)

      json(conn, %{
        entries: entries,
        metadata: PaginationHelpers.metadata_json(result.metadata)
      })
    else
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(ApiHelpers.generate_error(reason, "Invalid request"))
    end
  end
end
