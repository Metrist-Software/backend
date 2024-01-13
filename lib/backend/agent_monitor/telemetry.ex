defmodule Backend.AgentMonitor.Telemetry do
  @moduledoc """
  Agent monitoring telemetry as a PromEx plugin
  """
  use PromEx.Plugin

  @metric_name [:agent, :monitor]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :agent_monitor_telemetry,
      [
        last_value(@metric_name ++ [:is_up], tags: [:instance])
      ]
    )
  end

  def mark_up(instance), do: execute(instance, true)
  def mark_down(instance), do: execute(instance, false)

  defp execute(instance, is_up?) do
    value = if is_up?, do: 1, else: 0
    :telemetry.execute(
      @metric_name,
      %{is_up: value},
      %{instance: instance}
    )
  end
end
