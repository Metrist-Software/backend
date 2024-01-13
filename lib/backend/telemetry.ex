defmodule Backend.Telemetry do
  @moduledoc """
  The Telemetry context.
  """

  import Ecto.Query, warn: false
  alias Backend.TelemetryRepo

  alias Backend.Telemetry.TelemetryEntry

  @valid_aggregates [:min, :max, :mean, :p50, :p75, :p80, :p95, :p99]

  def list_monitor_telemetry(from, repo \\ TelemetryRepo) when from != :nil do
    query = from t in TelemetryEntry,
      where: t.time > type(^from, :utc_datetime_usec)

    repo.all(query)
  end

  def create_telemetry_entry(attrs \\ %{}) do
    %TelemetryEntry{}
    |> TelemetryEntry.changeset(attrs)
    |> TelemetryRepo.insert()
  end

  def list_monitor_telemetry_as_map(from, repo \\ TelemetryRepo, opts \\ []) do
    query = from t in TelemetryEntry,
      where: t.time > type(^from, :utc_datetime_usec),
      select: map(t, [:account_id, :check_id, :instance_id, :monitor_id, :time, :value])
    repo.all(query, opts)
  end

  def get_last_entry(repo \\ TelemetryRepo) do
    query = from t in TelemetryEntry,
      select: max(t.time)

    repo.one(query)
  end

  def create_multiple_entries(entries) when is_list(entries) do
    TelemetryRepo.insert_all(TelemetryEntry, entries)
  end

  def average_per_mci(from, to, monitor_ids, account_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    instance_id = Keyword.get(opts, :instance_id, nil)
    instances = Keyword.get(opts, :instances, nil)
    checks = Keyword.get(opts, :checks, nil)
    include_shared = Keyword.get(opts, :include_shared, false)

    timebucket_seconds = average_per_mci_timebucket_seconds(from, to)

    query = from t in TelemetryEntry,
      where: t.time >= type(^from, :utc_datetime_usec),
      order_by: [asc: fragment("bucket")],
      select: %{
          t |
          time: fragment(
            "time_bucket(?, time) + ? as bucket",
            ^%Postgrex.Interval{secs: timebucket_seconds},
            ^%Postgrex.Interval{secs: trunc(timebucket_seconds / 2)}
          ),
          value: avg(t.value),
        },
      group_by: [fragment("bucket"), t.account_id, t.instance_id, t.monitor_id, t.check_id],
      limit: ^limit

    query = if instance_id, do: (from t in query, where: t.instance_id == ^instance_id), else: query
    query = if instances && not Enum.empty?(instances), do: (from t in query, where: t.instance_id in ^instances), else: query
    query = if checks && not Enum.empty?(checks), do: (from t in query, where: t.check_id in ^checks), else: query
    query = if instance_id, do: (from t in query, where: t.instance_id == ^instance_id), else: query
    query = if to != nil, do: (from t in query, where: t.time <= type(^to, :utc_datetime_usec)), else: query
    query =
      cond do
        account_id && include_shared && account_id != "SHARED" ->
          (from t in query, where: t.account_id == ^account_id or t.account_id == "SHARED")
        account_id ->
          (from t in query, where: t.account_id == ^account_id)
        true ->
          (from t in query, where: t.account_id == "SHARED")
      end

      query = if monitor_ids, do: (from t in query, where: t.monitor_id in ^monitor_ids), else: query

      TelemetryRepo.all(query)
  end

  def get_aggregates_for_monitor(from, monitorId, account_id, instance \\ nil) do
    query = from t in TelemetryEntry,
      where: t.time > type(^from, :utc_datetime_usec) and t.monitor_id == ^monitorId,
      group_by: [t.check_id],
      select: %{check_id: t.check_id, count: count(t.time), mean: avg(t.value), min: min(t.value), max: max(t.value)}

    query = if account_id,
      do: (from t in query, where: t.account_id == ^account_id),
      else: (from t in query, where: t.account_id == "SHARED")
    query = if is_nil(instance) || instance == "all",
      do: query,
      else: (from t in query, where: t.instance_id == ^instance)

    TelemetryRepo.all(query)
  end

  @doc """
  Get aggregate telemetry over a time_bucket (ex. "1 day", "3 days", "1 minute", "10 seconds" etc.any()
  from should be a utc datetime
  aggregate can be :min, :max, :mean, :p50, :p75, :p80, :p95, :p99
  opts is a list of optional arguments. It can include :account_id, :monitor_id,
  and :check_id to filter based on the corresponding field and :group_by_instance
  to indicate whether the query should group on instance_id and include it in the result
  need can make things a lot cheaper.
  """
  def get_aggregate_telemetry(from, time_bucket, monitor_id, aggregate, opts \\ []) do
    opts = Enum.into(opts, %{account_id: nil, instance_id: nil, check_id: nil, group_by_instance: false, gap_fill: false})

    [amount, period] = String.split(time_bucket, " ")
    {floatAmount, _} = Float.parse(amount)

    (from t in TelemetryEntry,
      where: t.time > type(^from, :utc_datetime_usec) and t.monitor_id == ^monitor_id,
      group_by: [fragment("t2"), t.check_id],
      order_by: fragment("t2"))
    |> add_filter([instance_id: opts.instance_id])
    |> add_filter([check_id: opts.check_id])
    |> add_filter([account_id: opts.account_id || "SHARED"])
    |> add_aggregate_or_gapfill(aggregate, period, floatAmount, from, NaiveDateTime.utc_now(), opts.gap_fill)
    |> do_group_by_instance(opts.group_by_instance)
    |> TelemetryRepo.all
    |> filter_gapfill_zeros(opts.gap_fill)
  end

  defp add_filter(query, [{_, nil}]), do: query
  defp add_filter(query, filter) do
    from t in query,
    where: ^filter
  end

  defp do_group_by_instance(query, false), do: query
  defp do_group_by_instance(query, true) do
    from t in query,
    group_by: [t.instance_id],
    select_merge: %{instance_id: t.instance_id}
  end


  defp add_aggregate_or_gapfill(query, aggregate, period, floatAmount, from, to, true) do
    query
    |> add_gapfill_aggregate(aggregate, period, floatAmount, from, to)
  end
  defp add_aggregate_or_gapfill(query, aggregate, period, floatAmount, _from, _to, _) do
    query
    |> add_aggregate(aggregate, period, floatAmount)
  end

  percentile = fn p -> "percentile_cont(#{p}) within group (order by ?)" end
  aggregations = %{
    mean: "avg(?)",
    min: "min(?)",
    max: "max(?)",
    p50: percentile.(0.5),
    p75: percentile.(0.75),
    p80: percentile.(0.80),
    p95: percentile.(0.95),
    p99: percentile.(0.99),
  }

  # see https://dev.to/lessless/manipulating-intervals-in-ecto-fragments-3ofl
  for {aggr, snippet} <- aggregations do
    def add_aggregate(query, unquote(aggr), period, floatAmount) do
      from t in query, select: %{
        time: fragment("time_bucket(('1 ' || ?)::interval * ?::float, time) as t2", ^period, ^floatAmount),
        check_id: t.check_id,
        value: fragment(unquote(snippet), t.value),
        count: fragment("count(*)")
      }
    end

    def add_gapfill_aggregate(query, unquote(aggr), period, floatAmount, from, to) do
      from t in query, select: %{
        time: fragment("time_bucket_gapfill(('1 ' || ?)::interval * ?::float, time, start => ?, finish => ?) as t2", ^period, ^floatAmount, ^from, ^to),
        check_id: t.check_id,
        value: fragment(unquote("COALESCE(#{snippet}, 0)"), t.value),
        count: fragment("count(*)")
      }
    end
  end
  def add_aggregate(_, aggr, _, _) do
    raise ~s/Invalid aggregate "#{aggr}". Valid aggregates are #{Enum.join(@valid_aggregates, ",")}./
  end

  def get_telemetry_report(monitor_logical_name, instance, timespan, aggregate, account_id) do
    instance = if instance == "all", do: nil, else: instance

    {lookback, interval, _} = timespan_to_timescale(timespan)
    from_time = DateTime.add(DateTime.utc_now(), -lookback, :second)

    account_check_map = create_check_map(from_time, interval, monitor_logical_name, instance, aggregate, account_id)
    check_aggregates = get_aggregates_for_monitor(from_time, monitor_logical_name, account_id, instance)
    baseline_check_map = create_check_map(from_time, interval, monitor_logical_name, instance, aggregate, nil)
    baseline_check_aggregates = get_aggregates_for_monitor(from_time, monitor_logical_name, nil, instance)

    %{
      checks: account_check_map,
      baseline_checks: baseline_check_map,
      check_aggregates: check_aggregates,
      baseline_check_aggregates: baseline_check_aggregates
    }
  end

  def get_check_telemetry(logical_name, check_id, timespan, aggregate, account_id) do
    {lookback, interval, _} = timespan_to_timescale(timespan)
    from_time = DateTime.add(DateTime.utc_now(), -lookback, :second)

    get_aggregate_telemetry(
      from_time,
      interval,
      logical_name,
      aggregate_to_timescale(aggregate),
      account_id: account_id,
      check_id: check_id,
      group_by_instance: true
    )
  end

  defp create_check_map(fromTime, interval, monitor_logical_name, instance, aggregate, account_id) do
    checkTelemetry = get_aggregate_telemetry(
      fromTime,
      interval,
      monitor_logical_name,
      aggregate_to_timescale(aggregate),
      account_id: account_id,
      instance_id: instance
    )

    Enum.reduce(checkTelemetry, %{},
      fn x, acc ->
        check_id = Map.get(x, :check_id)
        filtered_list = Enum.filter(checkTelemetry, fn x -> Map.get(x, :check_id) == check_id end)
        Map.put_new(acc, check_id, filtered_list)
      end)
  end

  @spans  %{
               # lookback (secs), grouping (string), grouping (secs)
    "hour" =>   {      3_600,      "15 seconds",                15},
    "day"  =>   {     86_400,      "15 minutes",           15 * 60},
    "week" =>   { 7 * 86_400,      "1 hour",               60 * 60},
    "month" =>  {30 * 86_400,      "12 hours",        12 * 60 * 60},
    "90day" =>  {90 * 86_400,      "12 hours",        12 * 60 * 60}
  }
  def timespan_to_timescale(timespan) do
    Map.get(@spans, timespan, @spans["week"])
  end

  def cutoff_for_timespan(timespan) do
    {lookback, _, _} = timespan_to_timescale(timespan)
    DateTime.utc_now() |> DateTime.add(-lookback, :second)
  end

  defp aggregate_to_timescale(aggregate) do
    case aggregate do
      "MIN" -> :min
      "MAX" -> :max
      "MEAN" -> :mean

      #Backend.Telemetry supports more than this but this is all the UI supports right now.
      #See Backend.Telemetry.@valid_aggregates
    end
  end

  # filter zeros that occur at end of time range
  defp filter_gapfill_zeros(checks, true) do
    last_check = checks |> List.last(%{ time: nil })
    time = last_check[:time]
    checks |> Enum.reject(fn %{ time: t, value: v } -> t == time and v == 0 end)
  end
  defp filter_gapfill_zeros(checks, _gap_filled?), do: checks

  defp average_per_mci_timebucket_seconds(from, to) do
    timerange_gap_minutes = trunc(NaiveDateTime.diff(to, from, :millisecond) / :timer.minutes(1))
    timebucket_minutes = max(trunc(timerange_gap_minutes / 60), 1) * 5
    timebucket_minutes * 60
  end
end
