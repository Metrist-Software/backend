defmodule Backend.Projections.Dbpa.IssueEvent do
  use Ecto.Schema
  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Dbpa.IssueEvent

  @valid_states Backend.Projections.Dbpa.MonitorEvent.states()
  @sources [:status_page, :monitor]

  @primary_key {:id, :string, []}
  @foreign_key_type :string
  schema "issue_events" do
    field :check_logical_name, :string
    field :component_id, :string
    field :region, :string
    field :source, Ecto.Enum, values: @sources
    # This ID refers to a status page component change OR a monitor event id
    field :source_id, :string
    field :state, Ecto.Enum, values: @valid_states
    field :start_time, :naive_datetime_usec

    timestamps()

    belongs_to :issue, Backend.Projections.Dbpa.Issue
  end

  @ecto_order_by [{:desc, :start_time}, {:desc, :id}]
  @paginator_cursor_fields [:start_time, :id]

  def list_issue_events_paginated(account_id, params) do
    limit = params[:limit]
    cursor_after = params[:cursor_after]
    cursor_before = params[:cursor_before]

    query =
      IssueEvent
      |> where(^filter_where(params))
      |> order_by(^@ecto_order_by)
      |> put_query_prefix(Repo.schema_name(account_id))

    Backend.Repo.paginate(
      query,
      cursor_fields: @paginator_cursor_fields,
      sort_direction: :desc,
      limit: limit,
      after: cursor_after,
      before: cursor_before
    )
  end

  def services_impacted_count(account_id, issue_id) do
    IssueEvent
    |> select([e], %{
      issue_id: e.issue_id,
      feature_count: fragment("count(distinct coalesce(?, ?))", e.check_logical_name, e.component_id),
      region_count: fragment("count(distinct ?)", e.region)
    })
    |> group_by([e], e.issue_id)
    |> where(^filter_where(issue_id: issue_id))
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Backend.Repo.all()
  end

  def filter_where(params) do
    Enum.reduce(params, dynamic(true), fn
      {_, nil}, dynamic ->
        dynamic

      {:start_time_after, value}, dynamic ->
        dynamic([i], ^dynamic and i.start_time > ^value)

      {:start_time_before, value}, dynamic ->
        dynamic([i], ^dynamic and i.start_time < ^value)

      {:state, value}, dynamic when is_list(value) ->
        dynamic([e], ^dynamic and e.state in ^value)

      {:state, value}, dynamic ->
        dynamic([e], ^dynamic and e.state == ^value)

      {:region, value}, dynamic when is_list(value) ->
        dynamic([e], ^dynamic and e.region in ^value)

      {:region, value}, dynamic ->
        dynamic([e], ^dynamic and e.region == ^value)

      {:issue_id, value}, dynamic when is_list(value) ->
        dynamic([e], ^dynamic and e.issue_id in ^value)

      {:issue_id, value}, dynamic ->
        dynamic([e], ^dynamic and e.issue_id == ^value)

      {:source, value}, dynamic when is_list(value) ->
        dynamic([e], ^dynamic and e.issue_id in ^value)

      {:source, value}, dynamic ->
        dynamic([e], ^dynamic and e.issue_id == ^value)

      {_, _}, dynamic ->
        dynamic
    end)
  end
end
