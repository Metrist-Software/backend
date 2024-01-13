defmodule Backend.AgentMonitor do
  @moduledoc """
  API to agent monitoring subsystem
  """

  @doc """
  Register a heartbeat for the agent instance. This will either start a new monitor
  or update an existing one.
  """
  defdelegate heartbeat(instance_name), to: Backend.AgentMonitor.Worker
end
