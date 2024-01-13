defmodule Backend.TelemetryToLocal do
  use GenServer

  alias Backend.TelemetrySourceRepo
  alias Backend.Telemetry

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    TelemetrySourceRepo.start_link(opts.connectionParams)
    last_entry = Telemetry.get_last_entry()
    default_start = DateTime.add(DateTime.utc_now(), -1 * (7 * 86_400))

    start_datetime =
      if !last_entry || last_entry < default_start,
        do: DateTime.add(DateTime.utc_now(), -1 * (7 * 86_400), :second),
        else: last_entry

    send(self(), :work)
    {:ok, %{source: opts.source, lastRunTime: start_datetime}}
  end

  def handle_info(:work, state) do
    Logger.debug("Loading data from #{state.source} starting at #{state.lastRunTime}")

    # An initial load may take some time on a slower internet connection, set a comfortably high timeout
    Telemetry.list_monitor_telemetry_as_map(state.lastRunTime, TelemetrySourceRepo,
      timeout: 300_000
    )
    |> Enum.chunk_every(5000)
    |> Enum.each(
      fn telems ->
        Telemetry.create_multiple_entries(telems)
        Enum.each(telems, &generate_telemetry_commands/1)
      end)

    schedule_work()
    {:noreply, %{state | lastRunTime: DateTime.utc_now()}}
  end

  defp generate_telemetry_commands(telem) do
    # We don't want to do this when we're bringing in initial huge batches if we haven't run to_local for a while
    # We are simulating real time here not simulating 40,000+ backlog so only emit if it was in the last 5 mins
    # Limited to SHARED telem (since all local should have SHARED)
    if (telem.account_id == "SHARED" && NaiveDateTime.diff(NaiveDateTime.utc_now(), telem.time) < 300) do
        cmd = %Domain.Monitor.Commands.AddTelemetry{
          id: Backend.Projections.construct_monitor_root_aggregate_id(telem.account_id, telem.monitor_id),
          check_logical_name: telem.check_id,
          instance_name: telem.instance_id,
          is_private: telem.account_id != "SHARED",
          value: telem.value,
          report_time: NaiveDateTime.utc_now()
        }

        # Dispatching with local_copy actor so that we don't double write to timescale locally.
        Backend.App.dispatch_with_actor(Backend.Auth.Actor.local_copy(), cmd)
    end
  end

  defp schedule_work() do
    # 30 seconds
    Process.send_after(self(), :work, 1 * 30 * 1000)
  end
end
