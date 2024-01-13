defmodule Backend.Projections.Dbpa.MonitorError do
  use Ecto.Schema
  require Logger

  @primary_key {:id, :string, []}
  schema "monitor_errors" do
    field :monitor_logical_name, :string
    field :check_logical_name, :string
    field :instance_name, :string
    field :message, :string
    field :time, :naive_datetime_usec
    field :blocked_steps, {:array, :string}
    field :is_valid, :boolean

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo


  def monitor_errors(account_id, logical_name \\ nil, timespan \\ nil, group_by_check \\ true, order_ascending \\ true) do
    __MODULE__
    |> with_timespan(timespan)
    |> with_monitor(logical_name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> apply_order_by(order_ascending)
    |> Repo.all()
    |> with_check_group_by(group_by_check)
  end

  def monitor_errors_paged(account_id, logical_name, opts \\ []) do
    order = Keyword.fetch!(opts, :order)
    group_by_check = Keyword.get(opts, :group_by_check, false)
    timespan = Keyword.get(opts, :timespan)
    before_cursor = Keyword.get(opts, :before_cursor)
    after_cursor = Keyword.get(opts, :after_cursor)

    %{entries: entries, metadata: metadata} =
      __MODULE__
      |> with_timespan(timespan)
      |> with_monitor(logical_name)
      |> where([e], e.is_valid == true)
      |> put_query_prefix(Repo.schema_name(account_id))
      |> order_by([e], [{^order, e.time}, {^order, e.id}])
      |> Repo.paginate(
        before: before_cursor,
        after: after_cursor,
        cursor_fields: [{:time, order}, {:id, order}],
        limit: 20
      )

    %{entries: entries |> with_check_group_by(group_by_check), metadata: metadata}
  end

  def count_per_mci(account_id, monitor_ids, from, to, opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)
    cursor_after = Keyword.get(opts, :cursor_after)
    cursor_before = Keyword.get(opts, :cursor_before)
    checks = Keyword.get(opts, :checks)
    instances = Keyword.get(opts, :instances)

    query =
    __MODULE__
    |> with_monitor(monitor_ids)
    |> with_from(from)
    |> with_to(to)
    |> with_checks(checks)
    |> with_instances(instances)
    |> select([e], %{
      time: fragment("date_trunc(?, ?) as t0", ^raw_query_precision(from, to), e.time),
      monitor_logical_name: e.monitor_logical_name,
      check_logical_name: e.check_logical_name,
      instance_name: e.instance_name,
      count: count(e.id)
    })
    |> group_by([e], [fragment("t0"), e.monitor_logical_name, e.instance_name, e.check_logical_name])
    |> put_query_prefix(Repo.schema_name(account_id))
    |> order_by([e], [fragment("t0"), e.monitor_logical_name])

    Repo.paginate(
      query,
      before: cursor_before,
      after: cursor_after,
      cursor_fields: [:time, :monitor_logical_name],
      limit: limit
    )
  end

  def raw_query_precision(from, to) do
    minute = NaiveDateTime.diff(to, from, :minute)
    cond do
      minute < 120 -> "minute" # 2 hours
      minute < 7200 -> "hour"  # 5 days
      true -> "day"
    end
  end

  defp with_from(query, nil), do: query
  defp with_from(query, from), do: query |> where([e], e.time >= ^from)

  defp with_to(query, nil), do: query
  defp with_to(query, to), do: query |> where([e], e.time <= ^to)

  defp apply_order_by(query, order_ascending) do
    case order_ascending do
      true ->
        query
        |> order_by([e], asc: e.time)
      false ->
        query
        |> order_by([e], desc: e.time)
    end
  end

  defp with_check_group_by(initial_list, should_group_by_check) do
    case should_group_by_check do
      true ->
        initial_list
        |> Enum.reduce(%{}, fn e, acc ->
              Map.update(acc, e.check_logical_name, [e], fn l -> [e | l] end)
        end)
      _ ->
        initial_list
    end
  end

  defp with_monitor(query, nil), do: query
  defp with_monitor(query, []), do: query
  defp with_monitor(query, logical_name) when is_list(logical_name) do
    query
    |> where([e], e.monitor_logical_name in ^logical_name)
  end

  defp with_monitor(query, logical_name) do
    query
    |> where([e], e.monitor_logical_name == ^logical_name)
  end

  defp with_checks(query, nil), do: query
  defp with_checks(query, []), do: query
  defp with_checks(query, checks) when is_list(checks) do
    query
    |> where([e], e.check_logical_name in ^checks)
  end

  defp with_instances(query, nil), do: query
  defp with_instances(query, []), do: query
  defp with_instances(query, instances) when is_list(instances) do
    query
    |> where([e], e.instance_name in ^instances)
  end

  defp with_timespan(query, timespan) do
    case timespan do
      nil -> query
      _ ->
        cutoff = Backend.Telemetry.cutoff_for_timespan(timespan)
        query
        |> where([e], e.time > ^cutoff)
    end
  end
end
