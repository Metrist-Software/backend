defmodule Backend.Twitter.Worker do
  @moduledoc """
  Worker process. This process is responsible for keeping things up-to-date
  for a single monitor/hashtag.
  """
  require Logger
  use GenServer

  alias Backend.Projections.Dbpa.MonitorTwitterCounts

  # Our buckets always span the 15 minutes up to the timestamp.
  @bucket_size_s 15 * 60
  @bucket_limit floor(86_400 / @bucket_size_s)

  # To make testing somewhat easier we inject deps.
  @deps %{
    twitter_client: Backend.Twitter.Client,
    commanded_app: Backend.App,
    ndt_source: NaiveDateTime
  }

  defmodule State do
    defstruct monitor_logical_name: nil,
              hashtag: nil,
              counts: []
  end

  def start_link(monitor_logical_name, hashtag) do
    case GenServer.start_link(__MODULE__, {monitor_logical_name, hashtag}) do
      {:ok, pid} ->
        Logger.info("Twitter counter #{monitor_logical_name}/##{hashtag} started as #{inspect pid}}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("Twitter counter #{monitor_logical_name}/##{hashtag} already started as #{inspect pid}")
        :ignore
    end
  end

  def counts(pid) do
    GenServer.call(pid, :counts)
  end

  # Server side

  def init({monitor_logical_name, hashtag}) do
    counts =
      for record <- MonitorTwitterCounts.get(monitor_logical_name, hashtag) do
        # Note that for now we ignore the bucket duration in these records - it's there
        # so we can change the duration on the fly if needed and for external use, but
        # currently it's always going to be @bucket_size_s.
        {naive_to_unix(record.bucket_end_time), record.count}
      end

    schedule_tick(counts)
    {:ok, %State{monitor_logical_name: monitor_logical_name, hashtag: hashtag, counts: counts}}
  end

  def handle_call(:counts, _from, state) do
    {:reply, state.counts, state}
  end

  # Stops the worker if `state.hashtag` is not in `hashtags`
  def handle_call({:maybe_stop, hashtags}, _from, state) do
   if Enum.member?(hashtags, state.hashtag) do
    {:reply, :not_stopped, state}
   else
    Logger.info("Stopping worker for #{state.monitor_logical_name}/##{state.hashtag}")
    {:stop, :normal, :ok, state}
   end
  end

  def handle_info(action, state, deps \\ @deps)

  def handle_info(:tick, state, deps) do
    do_schedule_tick()
    Logger.info("Fetching twitter counts for #{state.monitor_logical_name}/##{state.hashtag}")
    now = deps.ndt_source.utc_now()
    since = NaiveDateTime.add(now, -@bucket_size_s, :second)
    count = deps.twitter_client.count_tweets(state.hashtag, since)

    # Update state
    counts = state.counts ++ [{naive_to_unix(now), count}]

    counts =
      if Enum.count(counts) > @bucket_limit,
        do: Enum.slice(counts, 1, @bucket_limit),
        else: counts

    # Send command out
    command = %Domain.Monitor.Commands.AddTwitterCount{
      id:
        Backend.Projections.construct_monitor_root_aggregate_id(
          "SHARED",
          state.monitor_logical_name
        ),
      hashtag: state.hashtag,
      bucket_end_time: now,
      bucket_duration: @bucket_size_s,
      count: count
    }

    deps.commanded_app.dispatch_with_actor(Backend.Auth.Actor.backend_code(), command)

    {:noreply, %State{state | counts: counts}}
  end

  def handle_info({:swarm, :die}, state, _deps) do
    {:stop, :shutdown, state}
  end

  defp schedule_tick([]) do
    # If we don't have anything yet, go for it straight away.
    do_schedule_tick(0)
  end

  defp schedule_tick(bucket_values) do
    {ts, _v} = List.last([{0, 0} | bucket_values])
    next = ts + @bucket_size_s
    now = :erlang.system_time(:second)
    delta_s = max(next - now, 0)
    do_schedule_tick(delta_s)
  end

  defp do_schedule_tick(delta_s \\ @bucket_size_s) do
    Process.send_after(self(), :tick, delta_s * 1_000)
  end

  defp naive_to_unix(ndt),
    do:
      ndt
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()
end
