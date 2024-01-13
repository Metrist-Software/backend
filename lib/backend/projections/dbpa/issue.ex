defmodule Backend.Projections.Dbpa.Issue do
  use Ecto.Schema
  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Dbpa.Issue

  @valid_states Backend.Projections.Dbpa.MonitorEvent.states()
  @sources [:status_page, :monitor]

  @primary_key {:id, :string, []}
  schema "issues" do
    field :sources, {:array, Ecto.Enum}, values: @sources
    field :worst_state, Ecto.Enum, values: @valid_states
    field :service, :string
    field :start_time, :naive_datetime_usec
    field :end_time, :naive_datetime_usec
    timestamps()

    has_many :events, Backend.Projections.Dbpa.IssueEvent
  end

  @ecto_order_by [{:desc, :start_time}, {:desc, :id}]
  @paginator_cursor_fields [:start_time, :id]

  def list_issues_paginated(account_id, params) do
    limit = params[:limit]
    cursor_after = params[:cursor_after]
    cursor_before = params[:cursor_before]

    query =
      Issue
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

  def filter_where(params) do
    Enum.reduce(params, dynamic(true), fn
      {:start_time_after, value}, dynamic ->
        dynamic([i], ^dynamic and i.start_time > ^value)

      {:start_time_before, value}, dynamic ->
        dynamic([i], ^dynamic and i.start_time < ^value)

      {:worst_state, value}, dynamic when is_list(value) ->
        dynamic([i], ^dynamic and i.worst_state in ^value)

      {:worst_state, value}, dynamic ->
        dynamic([i], ^dynamic and i.worst_state == ^value)

      {:service, value}, dynamic when is_list(value) ->
        dynamic([i], ^dynamic and i.service in ^value)

      {:service, value}, dynamic ->
        dynamic([i], ^dynamic and i.service == ^value)

      {_, _}, dynamic ->
        dynamic
    end)
  end
end
