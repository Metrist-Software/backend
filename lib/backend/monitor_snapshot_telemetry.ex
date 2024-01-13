defmodule Backend.MonitorSnapshotTelemetry do
  @moduledoc """
  Module that keeps track of the snapshot data

  We will only keep track of SHARED account for now
  """
  use PromEx.Plugin

  @metric_prefix [:backend, :monitor_snapshot]

  alias Backend.Projections.Dbpa.Snapshot.Snapshot

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :backend_monitor_snapshot,
      [
        # Keep track of the monitor's state (0 - Up, 1 - Degraded, 2 - Down)
        last_value(@metric_prefix ++ [:state],
          description: "The state of the monitor",
          tags: [:monitor]
        )
      ]
    )
  end

  def maybe_execute_metric(
        "SHARED",
        monitor_logical_name,
        %Snapshot{state: old_state},
        %Snapshot{state: new_state}
      )
      when old_state != new_state,
      do: execute_metric(monitor_logical_name, new_state)

  def maybe_execute_metric(
        "SHARED",
        monitor_logical_name,
        nil,
        %{state: new_state}
      ),
      do: execute_metric(monitor_logical_name, new_state)

  def maybe_execute_metric(_account_id, _monitor_logical_name, _old_snapshot, _new_snapshot),
    do: :ok

  def execute_metric(monitor_logical_name, state) do
    :telemetry.execute(
      @metric_prefix,
      %{state: Backend.Projections.Dbpa.Snapshot.get_state_weight(state)},
      %{
        monitor: monitor_logical_name
      }
    )
  end
end
