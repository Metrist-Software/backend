defmodule Backend.AgentMonitor.Supervisor do
  @moduledoc """
  This is the supervisor part of a simple agent monitoring solution.

  If an agent reports in with a Metrist API key (for now), we start
  a process that checks whether the agent is alive. An agent is alive
  if it reports in at least once every five minutes. If an agent is
  found to be dead, a telemetry event is sent so we can alert on it.

  We use Swarm to manage the cluster-wise processes.
  """

  def child_spec(_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def start_link() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: __MODULE__)
  end

  def start_child(instance_name) do
    DynamicSupervisor.start_child(__MODULE__, {Backend.AgentMonitor.Worker, [instance_name]})
  end

  def get_monitor(instance_name) do
    Swarm.whereis_or_register_name(
      worker_name(instance_name),
      __MODULE__,
      :start_child,
      [instance_name]
    )
  end

  def worker_name(instance_name), do: {Backend.AgentMonitor, instance_name}
end
