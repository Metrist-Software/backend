defmodule Backend.RealTimeAnalytics.SnapshottingHelpers do
  alias Backend.RealTimeAnalytics.{Snapshotting, MonitorEvents}
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail

  # Matches current check details to previous ones, dropping any from previous
  # that do not have a match in current
  @spec combine_check_details(list(CheckDetail.t()), list(CheckDetail.t())) :: %{required({any(), any()}) => %{previous: CheckDetail.t(), current: CheckDetail.t()}}
  def combine_check_details(previous_check_details, current_check_details) do
    previous_details = previous_check_details
    |> Enum.map(& {{&1.check_id, &1.instance}, &1})
    |> Map.new()

    current_check_details
    |> Enum.map(fn detail ->
      key = {detail.check_id, detail.instance}
      val = %{current: detail, previous: Map.get(previous_details, key)}

      {key, val}
    end)
    |> Map.new()
  end

  @spec did_state_transition?(
    %{:state => Snapshotting.state, optional(any()) => any()} | nil,
    %{:state => Snapshotting.state, optional(any()) => any()},
    MonitorEvents.t()) :: boolean()
    def did_state_transition?(nil, %{state: :blocked}, _outstanding_monitor_events), do: false
    def did_state_transition?(nil, %{state: state}, outstanding_monitor_events) do
    worst_outstanding_event_state = outstanding_monitor_events
    |> Enum.map(fn {_, _, _, _, state} -> state end)
    |> Enum.reduce(:up, &Backend.Projections.Dbpa.Snapshot.get_worst_state/2)

    worst_outstanding_event_state != state
  end
  def did_state_transition?(%{state: previous}, %{state: current}, _outstanding_monitor_events) when :blocked in [previous, current], do: false
  def did_state_transition?(%{state: previous}, %{state: current}, _outstanding_monitor_events) do
    previous != current
  end
end
