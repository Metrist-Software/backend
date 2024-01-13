defmodule Backend.AgentMonitor.Worker do
  @moduledoc """
  Process to keep an eye on an orchestrator. On every heartbeat received,
  we emit telemetry to indicate all is well; on a timeout, we emit telemetry
  to indicate all is not well.

  Note that we do not bother with state hand-off. If we restart on another node,
  we assume that the agent is healthy so the very worst case is that it takes
  ten minutes instead of five to discover this.
  """
  use GenServer
  require Logger

  @timeout_ms 5 * 60 * 1_000

  defmodule State do
    defstruct [:name, :healthy, :timer]
  end

  def start_link(instance_name) do
    GenServer.start_link(__MODULE__, [instance_name])
  end

  def heartbeat(instance_name) do
    case Backend.AgentMonitor.Supervisor.get_monitor(instance_name) do
      {:ok, pid} ->
        GenServer.cast(pid, :heartbeat)

      other ->
        Logger.warn(
          "Could not get running process for agent monitor #{instance_name}. Got #{inspect(other)}, ignoring"
        )
    end

    :ok
  end

  # server side

  @impl true
  def init(instance_name) do
    Logger.info("#{inspect(self())} Start monitoring agent '#{instance_name}'")
    Backend.AgentMonitor.Telemetry.mark_up(instance_name)
    {:ok, %State{name: instance_name, healthy: true, timer: schedule_timeout()}}
  end

  @impl true
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    # We don't care that much about keeping agent states at this point. The worst that can happen
    # is that we mark a down agent up for a bit.
    {:reply, :ignore, state}
  end

  @impl true
  def handle_cast(:heartbeat, state) do
    if !state.healthy do
      # We were down, now we're up
      Logger.info("#{inspect(self())} Received heartbeat on agent '#{state.name}', marking up")
      Backend.AgentMonitor.Telemetry.mark_up(state.name)
    end

    if state.timer != nil do
      Process.cancel_timer(state.timer)
    end

    {:noreply, %State{state | healthy: true, timer: schedule_timeout()}}
  end

  @impl true
  def handle_info(:timeout, state) do
    if state.healthy do
      # We were up, now we're down
      Logger.info("#{inspect(self())} Timeout on agent '#{state.name}', marking down")
      Backend.AgentMonitor.Telemetry.mark_down(state.name)
    end

    # No need to reschedule a timer - we're down until we get a heartbeat again
    {:noreply, %State{state | healthy: false, timer: nil}}
  end

  defp schedule_timeout do
    Process.send_after(self(), :timeout, @timeout_ms)
  end
end
