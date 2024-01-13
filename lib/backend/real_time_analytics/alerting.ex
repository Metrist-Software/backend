defmodule Backend.RealTimeAnalytics.Alerting do
  @moduledoc """
  Provides functionality for creating and sending alerts
  """

  # TODO: Manage alerting infrastructure through infra repo

  require Logger

  alias Backend.Projections.Dbpa.Snapshot.{Snapshot, CheckDetail}
  alias Backend.Projections.Dbpa.Monitor
  alias Backend.RealTimeAnalytics.{Snapshotting, SnapshottingHelpers, MonitorEvents}
  alias Domain.Account.Commands.Alert
  alias Backend.RealTimeAnalytics.Snapshotting

  @type account_id :: String.t()

  @doc """
  If possible, create alerts and dispatch them.

  "Possible" means that we have a snapshot to work from.
  """
  @spec maybe_create_and_dispatch_alerts(
          Snapshot.t() | nil,
          Snapshot.t() | nil,
          %Monitor{},
          account_id(),
          MonitorEvents.t()
        ) :: {:ok, non_neg_integer()}
  def maybe_create_and_dispatch_alerts(_, nil, _, _, _) do
    Logger.info("RTA Alerting: Current snapshot is nil, not alerting")
    {:ok, 0}
  end

  def maybe_create_and_dispatch_alerts(previous_snapshot, current_snapshot, monitor, account_id, outstanding_monitor_events) do
    alerts = create_alerts(previous_snapshot, current_snapshot, monitor, outstanding_monitor_events)
    dispatch_alerts(alerts, account_id)
    {:ok, length(alerts)}
  end

  @spec create_alerts(Snapshot.t() | nil, Snapshot.t(), %Monitor{}, MonitorEvents.t()) :: list(Alert.t())
  def create_alerts(previous_snapshot, current_snapshot, monitor, outstanding_monitor_events) do
    [
      create_monitor_alert(previous_snapshot, current_snapshot, monitor, outstanding_monitor_events),
      create_check_alert(previous_snapshot, current_snapshot, monitor, outstanding_monitor_events)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @spec create_monitor_alert(Snapshot.t() | nil, Snapshot.t(), %Monitor{}, MonitorEvents.t()) :: Alert.t() | nil
  def create_monitor_alert(previous_snapshot, current_snapshot, monitor, outstanding_monitor_events) do
    if SnapshottingHelpers.did_state_transition?(previous_snapshot, current_snapshot, outstanding_monitor_events)
       or did_status_page_component_checks_transitioned?(previous_snapshot, current_snapshot, outstanding_monitor_events)
      do
      do_create_monitor_alert(current_snapshot, monitor)
    else
      nil
    end
  end

  @spec get_relevant_outstanding_events(MonitorEvents.t(), {String.t(), String.t()}) :: MonitorEvents.t()
  defp get_relevant_outstanding_events(events, {check_id, instance_name}) do
    Enum.filter(events, fn
      {_, ^check_id, ^instance_name, _, _} -> true
      _ -> false
    end)
  end

  def did_status_page_component_checks_transitioned?(%Snapshot{} = previous_snapshot, %Snapshot{} = current_snapshot, outstanding_monitor_events) do
    SnapshottingHelpers.combine_check_details(previous_snapshot.status_page_component_check_details, current_snapshot.status_page_component_check_details)
    |> Enum.any?(fn {key, %{previous: previous, current: current}} ->
      SnapshottingHelpers.did_state_transition?(previous, current, get_relevant_outstanding_events(outstanding_monitor_events, key))
    end)
  end
  def did_status_page_component_checks_transitioned?(_previous_snapshot, _current_snapshot, _), do: false

  @spec do_create_monitor_alert(Snapshot.t(), %Monitor{}) :: Alert.t()
  def do_create_monitor_alert(snapshot, monitor) do
    message = case snapshot.state do
      :up ->
        # This check ensures that we send an alert if one of the status page check details state is not up
        # We are building the message here because we don't want the actual snapshot state to be affected
        if Enum.all?(snapshot.status_page_component_check_details, & &1.state == :up) do
          "🎉 #{snapshot.message}"
        else
          "⚠️ #{monitor.name} is experiencing issues."
          |> add_check_details_to_message(snapshot)
        end

      :degraded ->
        "⚠️ #{snapshot.message}"
        |> add_check_details_to_message(snapshot)

      :issues ->
        "💥 #{snapshot.message}"
        |> add_check_details_to_message(snapshot)

      :down ->
        "🛑 #{snapshot.message}"
        |> add_check_details_to_message(snapshot)
    end

    slack_message = Backend.Slack.SlackBody.alert_message(snapshot, monitor)
    |> encode_json_message()

    teams_message = Backend.RealTimeAnalytics.TeamsBody.alert_message(snapshot, monitor)
    |> encode_json_message()

    formatted_messages = %{
      slack: slack_message,
      teams: teams_message,
      email: message,
      pagerduty: message
    }

    # We send a degraded alert if status page stuff isn't healthy and the snapshot state is still :up
    # Let's set the state on the alert to the actual state (:degraded in this case)
    state_for_alert = Snapshotting.notification_header_state(snapshot)

    %Alert{
      alert_id: Domain.Id.new(),
      correlation_id: snapshot.correlation_id,
      monitor_logical_name: snapshot.monitor_id,
      state: state_for_alert,
      is_instance_specific: false,
      subscription_id: nil,
      formatted_messages: formatted_messages,
      affected_regions: [],
      affected_checks: [],
      generated_at: NaiveDateTime.utc_now(),
      monitor_name: monitor.name
    }
  end

  @spec add_check_details_to_message(any, Snapshot.t()) :: nonempty_binary
  def add_check_details_to_message(message, %Snapshot{} = snapshot) do
    details_message = snapshot.check_details
    |> Enum.concat(snapshot.status_page_component_check_details)
    |> Enum.reject(& &1.state == :up)
    |> Enum.map(& "\t• #{&1.message}")
    |> Enum.join("\n")

    "#{message}\n#{details_message}"
  end

  @spec create_check_alert(
          %{:check_details => list(CheckDetail.t()), optional(any) => any()} | nil,
          Snapshot.t(),
          %Monitor{},
          MonitorEvents.t()
        ) :: Alert.t() | nil
  def create_check_alert(nil, current_snapshot, monitor, outstanding_monitor_events),
    do: create_check_alert(%{check_details: []}, current_snapshot, monitor, outstanding_monitor_events)

  def create_check_alert(previous_snapshot, current_snapshot, monitor, outstanding_monitor_events) do
    SnapshottingHelpers.combine_check_details(
      previous_snapshot.check_details,
      current_snapshot.check_details
    )
    |> Enum.map(fn {key, %{previous: previous, current: current}} ->
      if SnapshottingHelpers.did_state_transition?(previous, current, get_relevant_outstanding_events(outstanding_monitor_events, key)) do
        current
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> do_create_check_alert(current_snapshot, monitor)
  end

  @spec do_create_check_alert(list(CheckDetail.t()), Snapshot.t(), %Monitor{}) :: Alert.t() | nil
  def do_create_check_alert([], _snapshot, _monitor), do: nil

  def do_create_check_alert(check_details, snapshot, monitor) do
    worst_state =
      check_details
      |> Enum.map(& &1.state)
      |> Enum.reduce(:up, &Backend.Projections.Dbpa.Snapshot.get_worst_state/2)

    affected_instances =
      check_details
      |> Enum.map(& &1.instance)
      |> Enum.uniq()

    %Alert{
      alert_id: Domain.Id.new(),
      correlation_id: snapshot.correlation_id,
      monitor_logical_name: snapshot.monitor_id,
      state: worst_state,
      is_instance_specific: true,
      subscription_id: nil,
      formatted_messages: %{},
      affected_regions: affected_instances,
      affected_checks: check_details,
      generated_at: NaiveDateTime.utc_now(),
      monitor_name: monitor.name
    }
  end

  @spec dispatch_alerts(list(Alert.t()), binary()) :: list(Alert.t())
  def dispatch_alerts([], _account_id), do: []

  def dispatch_alerts(alerts, account_id) do
    cmd = %Domain.Account.Commands.AddAlerts{
      id: account_id,
      alerts: alerts
    }

    Backend.App.dispatch(cmd)

    Logger.info("Sending alerts")
  end

  def encode_json_message(message) do
    message
    |> Jason.encode()
    |> case do
      {:ok, json} ->
        json

      {:error, err} ->
        Logger.error(err)
        ""
    end
  end

  defdelegate mci_field(mci, field), to: Snapshotting
end
