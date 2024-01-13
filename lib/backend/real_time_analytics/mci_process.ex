defmodule Backend.RealTimeAnalytics.MCIProcess do
  @moduledoc """
  Monitor/Check/Instance process. This process is responsible for keeping the last
  hour of telemetry/errors around and a moving average of the past week's worth of
  telemetry.

  For average we keep up to 168 blocks (could be less if no data within an hour), 1 hour time buckets,
  to calculate the weekly average. Initial load of the buckets is
  done by the Loader via tsdb.  The average moving forward is kept up to date by this process.
  For errors/telemetry we keep data points for the past hour bounded at an upper limit of 100
  which is more than enough for snapshotting

  Note that, like everything, MCI processes are account scoped. Maybe they should be
  called AMCI processes? That sounded like a mouthful, though. And for most practical purposes, we
  can forget about the account stuff.
  """
  require Logger
  use GenServer
  use TypedStruct
  alias Backend.RealTimeAnalytics.SwarmSupervisor

  @negative_seconds_per_hour -3_600
  @bounded_error_telemetry_list_size 100

  # We limit change notifications to this rate.
  @broadcast_interval_ms 1_000

  @type error_value :: %{
    # Orchestrator stores the error message in this field.
    #  but Backend.Projections.Dbpa.MonitorError uses the :message field to store the error message
    #  Maybe we should rename error_id to message?
    error_id: binary(),
    blocked_steps: [binary()]
  }

  @type error :: {NaiveDateTime.t(), error_value()}

  typedstruct module: State, enforce: true do
    # Both these values are bounded lists - we keep an hour's worth of errors
    # and a week's worth of telemetry, both as `{timestamp, value}` tuples to save
    # some space. We keep, for now, dates as NaiveDateTime until memory concerns force us to
    # do less.
    field :mci, {binary(), binary(), binary(), binary()}
    field :errors, list(), default: []
    field :telemetry, list(), default: []
    field :averages, list({float(), integer(), NaiveDateTime.t}), default: []
    field :initialized, boolean(), default: false
    field :last_broadcast, integer, default: nil
    field :broadcast_delay_timer, reference, default: nil
  end


  def start_link(args) do
    name = args[:name]
    mci = args[:mci]
    Logger.debug("Starting RTA MCI process for: #{inspect(mci)}")
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def child_spec(args) do
    mci = args[:mci]
    %{
      id: mci,
      restart: :transient,
      shutdown: 60_000,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  @doc """
  Process a reset signal. This can happen if we restart things, reload from the database, whatever. We're guaranteed to
  get one such signal after startup.
  """
  def reset_with(pid, errors, telemetry, average_buckets) do
    GenServer.cast(pid, {
      :reset,
      errors |> enforce_limit(),
      telemetry |> enforce_limit(),
      average_buckets}
    )
  end

  def average(pid_or_name) do
    GenServer.call(pid_or_name, :average)
  end

  def telemetry(pid_or_name) do
    GenServer.call(pid_or_name, :telemetry)
  end

  @spec errors(term()) :: [error()]
  def errors(pid_or_name) do
    GenServer.call(pid_or_name, :errors)
  end

  def mci(pid_or_name) do
    GenServer.call(pid_or_name, :mci)
  end

  def stop(pid_or_name) do
    GenServer.stop(pid_or_name)
  end

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    Process.send_after(self(), :verify_initialized, 45_000)

    {:ok, %State{mci: args[:mci]}, {:continue, []}}
  end


  @impl true
  def handle_continue(_args, state) do
    Logger.info("MCI: Registering mci process for #{inspect state.mci}")
    SwarmSupervisor.register_mci_process(state.mci, self())
    {:noreply, state}
  end

  @impl true
  def handle_call(:average, _from, state) do
    avg = case Enum.count(state.averages) do
        0 ->
          nil
        _ ->
          {sum, count} =
            state.averages
            |> Enum.reduce({0, 0}, fn {avg, count_in_bucket, _}, {sum, count} ->
              {sum + (count_in_bucket * avg), count + count_in_bucket}
            end)

          sum / count
      end

    {:reply, avg, state}
  end

  @impl true
  def handle_call(:telemetry, _from, state) do
    {:reply, state.telemetry, state}
  end

  @impl true
  def handle_call(:errors, _from, state) do
    {:reply, state.errors, state}
  end

  def handle_call(:mci, _from, state) do
    {:reply, state.mci, state}
  end

  # Oddly enough Swarm will not call this when a node is terminating only when new nodes start up and swarm wants to redistribute the processes (which we don't use)
  # If we want to send different state when terminating we have to do that in our Swarm.Tracker.handoff(state.mci, state) call
  # end_handoff always gets called and can be used to reset state vars in either scenario
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    Logger.info("MCI #{inspect state.mci} Starting state handoff PID: #{inspect self()}")
    {:reply, {:resume, state}, state}
  end

  def handle_cast({:swarm, :end_handoff, newState}, state) do
    Logger.info("MCI #{inspect state.mci}. Received state from swarm, setting it. PID: #{inspect self()}")
    {:noreply,  %{ newState | last_broadcast: nil, broadcast_delay_timer: nil}}
  end

  def handle_cast({:swarm, :resolve_conflict, _newState}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reset, errors, telemetry, average_bukets}, state) do
    send(self(), {:broadcast_change, "reset received"})
    {:noreply, %State{state | errors: errors, telemetry: telemetry, averages: average_bukets, initialized: true}}
  end

  # Updating this to use semantic comparison instead of
  # structural https://hexdocs.pm/elixir/1.12.3/NaiveDateTime.html#module-comparing-naive-date-times
  def handle_cast({:add_telemetry, timestamp, value}, state) do
    cutoff_date = NaiveDateTime.utc_now()
    |> NaiveDateTime.add(@negative_seconds_per_hour, :second)

    telemetry = state.telemetry ++ [{timestamp, value}]
    |> Enum.drop_while(fn {timestamp, _value} -> NaiveDateTime.compare(timestamp, cutoff_date) == :lt end)
    |> enforce_limit()

    send(self(), {:broadcast_change, "telemetry received"})
    {:noreply, %State{
      state |
      telemetry: telemetry,
      averages: update_averages_from_telemetry(state, {timestamp, value})
    }}
  end

  def handle_cast({:add_error, timestamp, value}, state) do
    cutoff_date = NaiveDateTime.utc_now()
    |> NaiveDateTime.add(@negative_seconds_per_hour, :second)

    errors = state.errors ++ [{timestamp, value}]
    |> Enum.drop_while(fn {timestamp, _value} -> NaiveDateTime.compare(timestamp, cutoff_date) == :lt end)
    |> enforce_limit()

    send(self(), {:broadcast_change, "error received"})
    {:noreply, %State{state | errors: errors}}
  end

  @impl true
  def handle_info({:broadcast_change, reason}, state) do
    now = :erlang.monotonic_time(:millisecond)
    not_before =
      if is_nil(state.last_broadcast) do
        # Make sure that we will broadcast the first time around.
        :erlang.monotonic_time(:millisecond) - @broadcast_interval_ms
      else
        state.last_broadcast + @broadcast_interval_ms
      end
    state =
      if now >= not_before do
        if monitor_name(state) != "metrist" do
          # Suppress this logging for the "metrist" monitor which we do expect to fire multiple times per second.
          Logger.info("MCI: broadcast monitor change for #{inspect state.mci}. PID: #{inspect self()}, reason: #{reason}")
        end
        Backend.PubSub.broadcast_rta_monitor_change(state.mci, self())
        %State{state | last_broadcast: now}
      else
        if monitor_name(state) != "metrist" do
          Logger.info("MCI: limiting change broadcast rate for #{inspect state.mci}. PID: #{inspect self()}, reason: #{reason}")
        end
        if not is_nil(state.broadcast_delay_timer), do: Process.cancel_timer(state.broadcast_delay_timer)
        timer = Process.send_after(self(), {:broadcast_change, "delay timer"}, not_before - now)
        %State{state | broadcast_delay_timer: timer}
      end
    {:noreply, state}
  end

  def handle_info({:swarm, :die}, state) do
    {:stop, :normal, state}
  end

  def handle_info(:verify_initialized, %State{ initialized: false } = state) do
    # This should only ever happen if the mci process started on its own due to a network split or
    # a hard kill
    # All MCI processes started through the loader have :reset called which sets initialized: true
    Logger.warn("MCI: Process not initialized after 45 seconds. Probably a network split or a hard down of a node. Requesting Loader reinitialization. #{inspect state.mci}")
    Backend.RealTimeAnalytics.Loader.request_initialization()
    {:noreply, state}
  end
  def handle_info(:verify_initialized, state), do: {:noreply, state}


  def update_averages_from_telemetry(state, {timestamp, value}) do
    case Enum.empty?(state.averages) do
      true -> [{value, 1, NaiveDateTime.utc_now()}]
      _ ->
        {last_avg, last_count, last_avg_timestamp} = List.last(state.averages)
        cut_off = last_avg_timestamp |> Timex.shift(hours: 1)
        case timestamp >= cut_off do
          true ->
            state.averages ++ [{value, 1, cut_off}]
          false ->
            # reverse so that head is the most recent average block
            [ _head | tail ] = Enum.reverse(state.averages)
            new_avg = reevaluate_average(last_avg, last_count, value)
            [{new_avg, last_count+1, last_avg_timestamp} | tail ]
            |> Enum.reverse()
        end
    end
    |> trim_averages()
  end

  defp trim_averages(list) do
    drop_cut_off = NaiveDateTime.utc_now()
    |> Timex.shift(weeks: -1)
    |> Timex.shift(hours: -1) # account for the fact that the first "block" may be up to an hour before weeks -1

    Enum.drop_while(list, fn {_, _, timestamp} -> NaiveDateTime.compare(timestamp, drop_cut_off) == :lt end)
  end

  defp reevaluate_average(current_average, count, added_value) do
    (current_average * count + added_value) / (count + 1)
  end

  defp enforce_limit(list) do
    list
    |> Enum.take(-@bounded_error_telemetry_list_size)
  end

  @impl true
  def terminate(:shutdown, state) do
    Logger.info("MCI: Beginning MCI process termination for #{inspect state.mci} from :shutdown. Starting handoff. PID: #{inspect self()}")
    Swarm.Tracker.handoff(state.mci, state)
  end
  @impl true
  def terminate(reason, state) do
    Logger.info("MCI: Beginning MCI process termination for #{inspect state.mci} from #{inspect reason}. PID: #{inspect self()}")
  end

  defp monitor_name(%State{mci: {_, monitor_name, _, _}}), do: monitor_name
end
