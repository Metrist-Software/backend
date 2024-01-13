defmodule Backend.Projections.Dbpa.MonitorEvent do
  use Ecto.Schema
  import Ecto.Query

  # Need :maintenance here for historical events
  @monitor_events_state [:up, :degraded, :blocked, :down, :issues, :maintenance, :unknown]

  @primary_key {:id, :string, []}
  schema "monitor_events" do
    field :monitor_logical_name, :string
    field :check_logical_name, :string
    field :instance_name, :string
    field :state, Ecto.Enum, values: @monitor_events_state
    field :message, :string
    field :start_time, :naive_datetime_usec
    field :end_time, :naive_datetime_usec
    field :correlation_id, :string
    field :is_valid, :boolean

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def outstanding_events(account_id, logical_name) do
    from(e in __MODULE__,
      where: e.monitor_logical_name == ^logical_name and is_nil(e.end_time),
      order_by: [desc: :inserted_at]
    )
    |> Backend.Repo.all(prefix: Backend.Repo.schema_name(account_id))
  end

  def outstanding_events(account_id) do
    from(e in __MODULE__,
      where: is_nil(e.end_time),
      order_by: [desc: :inserted_at]
    )
    |> Backend.Repo.all(prefix: Backend.Repo.schema_name(account_id))
  end

  def recent_monitor_event_by_state(account_id, logical_name, state) do
    from(e in __MODULE__,
      where: e.state == ^state and e.monitor_logical_name == ^logical_name,
      order_by: [desc: :inserted_at],
      limit: 1
    )
    |> Backend.Repo.one(prefix: Backend.Repo.schema_name(account_id))
  end

  def first_event_for_correlation_id(account_id, correlation_id) do
    from(e in __MODULE__,
      where: e.correlation_id == ^correlation_id,
      order_by: [asc: :inserted_at],
      limit: 1
    )
    |> Backend.Repo.one(prefix: Backend.Repo.schema_name(account_id))
  end

  def list_events(account_id, logical_name, start_time, end_time) do
    from(e in __MODULE__,
      where:
        e.monitor_logical_name == ^logical_name and e.start_time >= ^start_time and
          e.start_time <= ^end_time and
          e.is_valid == true,
      order_by: [asc: :start_time]
    )
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def events_by_correlation_id(account_id, monitor_ids, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    cursor_after = Keyword.get(opts, :cursor_after)
    cursor_before = Keyword.get(opts, :cursor_before)

    # TODO: The plugin we use for pagination doesn't seem to handle pagination
    # with a group_by, so will return inconsistent results.
    # This query was just quickly put together to build out the front end and
    # should most likely be scrapped in favour of a simpler query against more
    # suited underlying data

    from(e in __MODULE__,
      select: %{
        correlation_id: e.correlation_id,
        monitor_id:     e.monitor_logical_name,
        start_time:     min(e.start_time),
        end_time:       max(e.end_time),
        start_times:    fragment("array_agg(? order by ?)", e.start_time, e.start_time),
        check_ids:      fragment("array_agg(? order by ?)", e.check_logical_name, e.start_time),
        instance_ids:   fragment("array_agg(? order by ?)", e.instance_name, e.start_time),
        states:         fragment("array_agg(? order by ?)", e.state, e.start_time)
      },
      where: not is_nil(e.correlation_id),
      group_by: [e.correlation_id, e.monitor_logical_name],
      order_by: [desc: min(e.start_time)]
    )
    |> maybe_filter_on_monitors(monitor_ids)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.paginate(
      before: cursor_before,
      after: cursor_after,
      limit: limit,
      cursor_fields: [:start_time]
    )
  end

  defp maybe_filter_on_monitors(query, []), do: query
  defp maybe_filter_on_monitors(query, monitor_ids) do
    where(query, [e], e.monitor_logical_name in ^monitor_ids)
  end

  def states, do: @monitor_events_state
end
