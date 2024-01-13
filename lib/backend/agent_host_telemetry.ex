defmodule Backend.AgentHostTelemetry do
  @moduledoc """
  PromEx plugin for host telemetry we receive from agents.
  """
  use PromEx.Plugin

  @metric_name [:agent, :host_telemetry]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :agent_host_telemetry,
      [
        last_value(@metric_name ++ [:cpu],
          tags: [:instance]
        ),
        last_value(@metric_name ++ [:max_cpu],
          tags: [:instance]
        ),
        last_value(@metric_name ++ [:mem],
          tags: [:instance]
        ),
        last_value(@metric_name ++ [:disk],
          tags: [:instance]
        )
      ]
    )
  end

  def execute(metric_map) do

    :telemetry.execute(
      @metric_name,
      %{cpu: metric_map.cpu, mem: metric_map.mem, disk: metric_map.disk, max_cpu: metric_map.max_cpu},
      %{instance: metric_map.instance}
    )
  end
end
