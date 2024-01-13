defmodule Backend.Metrics do
  @moduledoc """
  Struct wrapper to hold dashboard metrics
  """

  defstruct [
    install_count: 0,
    active_user_count: 0,
    active_subscription_count: 0,
    command_count: 0,
    alert_count: 0,
    subscription_delivery_count: 0,
    down_event_count: 0,
    total_event_count: 0,
    timeseries_entry_count: 0,
    daily_active_web_users: 0,
    weekly_active_web_users: 0,
    monthly_active_web_users: 0,
    daily_active_slack_users: 0,
    weekly_active_slack_users: 0,
    monthly_active_slack_users: 0,
    daily_active_teams_users: 0,
    weekly_active_teams_users: 0,
    monthly_active_teams_users: 0,
    daily_api_requests: 0,
    weekly_api_requests: 0,
    monthly_api_requests: 0,
    daily_api_accounts: 0,
    weekly_api_accounts: 0,
    monthly_api_accounts: 0,
    daily_new_signups: 0,
    weekly_new_signups: 0,
    monthly_new_signups: 0,
    orchestrator_count: %{total: 0, accounts: 0},
    daily_signup_flows: %{},
    weekly_signup_flows: %{},
    monthly_signup_flows: %{}
  ]

  def fetch() do
    internal_account_ids = Backend.Projections.list_accounts(type: :internal)
      |> Enum.map(&(&1.id))

    %Backend.Metrics{
      install_count:                Backend.Projections.workspace_count(internal_account_ids),
      active_user_count:            Backend.Projections.active_user_count(internal_account_ids),
      command_count:                Backend.Projections.command_count(internal_account_ids),
      down_event_count:             Backend.Projections.down_event_count(),
      total_event_count:            Backend.Projections.total_event_count(),
      timeseries_entry_count:       timeseries_count(),
      active_subscription_count:    Backend.Projections.active_subscription_count(),
      alert_count:                  Backend.Projections.alert_count(),
      subscription_delivery_count:  Backend.Projections.subscription_delivery_count(),
      daily_active_web_users:       Backend.Projections.active_web_users(:daily),
      weekly_active_web_users:      Backend.Projections.active_web_users(:weekly),
      monthly_active_web_users:     Backend.Projections.active_web_users(:monthly),
      daily_active_slack_users:     Backend.Projections.active_slack_users(:daily),
      weekly_active_slack_users:    Backend.Projections.active_slack_users(:weekly),
      monthly_active_slack_users:   Backend.Projections.active_slack_users(:monthly),
      daily_active_teams_users:     Backend.Projections.active_teams_users(:daily),
      weekly_active_teams_users:    Backend.Projections.active_teams_users(:weekly),
      monthly_active_teams_users:   Backend.Projections.active_teams_users(:monthly),
      daily_api_requests:           Backend.Projections.api_count(:daily),
      weekly_api_requests:          Backend.Projections.api_count(:weekly),
      monthly_api_requests:         Backend.Projections.api_count(:monthly),
      daily_api_accounts:           Backend.Projections.active_api_accounts(:daily),
      weekly_api_accounts:          Backend.Projections.active_api_accounts(:weekly),
      monthly_api_accounts:         Backend.Projections.active_api_accounts(:monthly),
      daily_new_signups:            Backend.Projections.new_signups(:daily),
      weekly_new_signups:           Backend.Projections.new_signups(:weekly),
      monthly_new_signups:          Backend.Projections.new_signups(:monthly),
      # We want to specifically exclude SHARED from the orchestator count metrics
      orchestrator_count:           Backend.Projections.orchestrator_count([Domain.Helpers.shared_account_id() | internal_account_ids])
    }
  end

  def timeseries_count() do
    case Backend.EventStore.stream_info("TypeStream.Elixir.Domain.Monitor.Events.TelemetryAdded") do
      {:ok, %EventStore.Streams.StreamInfo{stream_version: count}} -> count
      _ -> 0
    end
  end

  def cleanup() do
    Backend.Projections.Aggregate.WebLoginAggregate.cleanup()
    Backend.Projections.Aggregate.AppUseAggregate.cleanup()
    Backend.Projections.Aggregate.ApiUseAggregate.cleanup()
  end
end
