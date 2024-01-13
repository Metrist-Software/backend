defmodule Backend.Projections do
  @moduledoc """
  The Projections context. This module contains all methods to access
  the default projections repo.
  """

  # NOTE when changing this file, please move - where possible - the functions
  # on the entity you're working on to the entity's module and replace with a defdelegate
  # here. That will keep the file size manageable.

  import Ecto.Query, warn: false
  alias Backend.Projections.Dbpa.StatusPage.StatusPageSubscription
  alias Backend.Repo

  alias Backend.Projections.{
    User,
    Account,
    SlackWorkspace,
    MicrosoftTenant,
    APIToken,
    MicrosoftTeamsCommand,
    SlackSlashCommand
  }

  alias Backend.Projections.Dbpa.{
    AnalyzerConfig,
    Instance,
    Invite,
    Monitor,
    MonitorCheck,
    MonitorConfig,
    MonitorEvent,
    MonitorInstance
  }

  alias Backend.Projections.Telemetry.MonitorTelemetry

  defdelegate list_users, to: User
  defdelegate list_users_for_account(account_id), to: User
  defdelegate get_user!(id), to: User
  defdelegate get_user(id), to: User
  defdelegate user_by_email(email), to: User
  defdelegate list_users_with_invites(account_id), to: User

  defdelegate list_accounts(opts \\ []), to: Account
  defdelegate list_account_ids(), to: Account
  defdelegate get_account(id, preloads \\ []), to: Account
  defdelegate get_account!(id), to: Account
  defdelegate register_account_activity(account_id), to: Account

  defdelegate list_invites(account_id), to: Invite
  defdelegate list_invites_with_emails(account_id), to: Invite
  defdelegate get_invite!(id, account_id), to: Invite
  defdelegate get_invites_for_user(user_id, account_id), to: Invite

  @spec get_slack_workspace(any) :: any
  def get_slack_workspace(id), do: Repo.get(SlackWorkspace, id)
  def get_microsoft_tenant(id), do: Repo.get(MicrosoftTenant, id)

  def get_api_token(id), do: Repo.get(APIToken, id)

  def list_api_tokens(account_id) do
    from(c in APIToken,
      where: c.account_id == ^account_id,
      select: [:api_token]
    )
    |> Repo.all()
    |> Enum.map(& &1.api_token)
  end

  def construct_monitor_root_aggregate_id(account_id, monitor_logical_name) do
    "#{account_id}_#{monitor_logical_name}"
  end

  def get_monitor(account_id, monitor_logical_name, preloads \\ []) do
    Repo.get(Monitor, monitor_logical_name, prefix: Repo.schema_name(account_id))
    |> Repo.preload(preloads)
  end

  def get_checks(account_id, monitor_logical_name) do
    from(c in MonitorCheck,
      where: c.monitor_logical_name == ^monitor_logical_name
    )
    |> Repo.all(prefix: Repo.schema_name(account_id))
  end

  def get_check(account_id, monitor_logical_name, check_id) do
    Repo.get_by(
      MonitorCheck,
      [logical_name: check_id, monitor_logical_name: monitor_logical_name],
      prefix: Repo.schema_name(account_id)
    )
  end

  def get_analyzer_config(account_id, monitor_logical_name) do
    Repo.get(AnalyzerConfig, monitor_logical_name, prefix: Repo.schema_name(account_id))
  end

  defdelegate get_checks_for_monitors(account_id, monitor_logical_names), to: MonitorCheck

  @spec get_analyzer_configs(any) :: any
  def get_analyzer_configs(account_id) do
    Repo.all(AnalyzerConfig, prefix: Repo.schema_name(account_id))
  end

  def get_instances(account_id) do
    Repo.all(Instance, prefix: Repo.schema_name(account_id))
  end

  def workspace_count(excluded_account_ids) do
    query =
      from t in MicrosoftTenant, where: t.account_id not in ^excluded_account_ids, select: t.id

    query =
      from s in SlackWorkspace,
        where: s.account_id not in ^excluded_account_ids,
        select: s.id,
        union: ^query

    Repo.one(from w in subquery(query), select: count("*"))
  end

  def active_user_count(excluded_account_ids) do
    slack_workspace_ids =
      Repo.all(
        from s in SlackWorkspace, where: s.account_id in ^excluded_account_ids, select: s.id
      )

    microsoft_teams_ids =
      Repo.all(
        from t in MicrosoftTenant, where: t.account_id in ^excluded_account_ids, select: t.id
      )

    query =
      from t in MicrosoftTeamsCommand,
        distinct: true,
        where: fragment("data #> '{Data, channelData, tenant, id}'") not in ^microsoft_teams_ids,
        select: %{id: fragment("data #> '{Data, from, id}'")}

    query =
      from s in SlackSlashCommand,
        distinct: true,
        where: fragment("data -> 'TeamId'") not in ^slack_workspace_ids,
        select: %{id: fragment("data -> 'UserId'")},
        union: ^query

    Repo.one(from w in subquery(query), select: count("*"))
  end

  def command_count(excluded_account_ids) do
    slack_workspace_ids =
      Repo.all(
        from s in SlackWorkspace, where: s.account_id in ^excluded_account_ids, select: s.id
      )

    microsoft_teams_ids =
      Repo.all(
        from t in MicrosoftTenant, where: t.account_id in ^excluded_account_ids, select: t.id
      )

    query =
      from t in MicrosoftTeamsCommand,
        where: fragment("data #> '{Data, channelData, tenant, id}'") not in ^microsoft_teams_ids,
        select: t.id

    query =
      from s in SlackSlashCommand,
        where: fragment("data -> 'TeamId'") not in ^slack_workspace_ids,
        select: s.id,
        union: ^query

    Repo.one(from w in subquery(query), select: count("*"))
  end

  # Doesn't seem to be a way to query across all schemas, just pulled from shared for now
  def down_event_count() do
    query = from e in MonitorEvent, where: e.state == :down, select: count("*")

    query
    |> put_query_prefix(Repo.schema_name("SHARED"))
    |> Repo.one()
  end

  def total_event_count() do
    query = from e in MonitorEvent, select: count("*")

    query
    |> put_query_prefix(Repo.schema_name("SHARED"))
    |> Repo.one()
  end
  defdelegate orchestrator_count(excluded_account_ids), to: MonitorTelemetry


  defdelegate get_monitor_configs(account_id, run_groups \\ nil), to: MonitorConfig

  defdelegate get_monitor_configs_by_monitor_logical_name(account_id, monitor_logical_name),
    to: MonitorConfig

  defdelegate get_monitor_config_by_name(account_id, monitor_logical_name),
    to: MonitorConfig

  defdelegate get_monitor_config_by_id(account_id, id), to: MonitorConfig

  def list_monitors(account_id, preloads \\ []) do
    from(m in Monitor, order_by: m.name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> preload(^preloads)
    |> Repo.all()
  end

  def monitor_with_checks_and_instances(account_id, logical_name) do
    from(m in Monitor, where: m.logical_name == ^logical_name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> preload([:instances, :checks])
    |> Repo.one()
  end

  def monitor_events(account_id, logical_name, timespan) do
    cutoff = Backend.Telemetry.cutoff_for_timespan(timespan)

    from(e in MonitorEvent,
      where: e.start_time > ^cutoff and e.monitor_logical_name == ^logical_name
    )
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  defdelegate recent_monitor_event_by_state(account_id, logical_name, state),
    to: Backend.Projections.Dbpa.MonitorEvent

  defdelegate first_event_for_correlation_id(account_id, correlation_id),
    to: Backend.Projections.Dbpa.MonitorEvent

  defdelegate list_all_instances(), to: MonitorInstance
  defdelegate get_monitor_instances(account_id, monitor_logical_name), to: MonitorInstance
  defdelegate get_monitor_instances_for_instance(account_id, instance_name), to: MonitorInstance
  defdelegate has_monitor_instances(account_id), to: MonitorInstance
  defdelegate get_active_monitor_instance_names(account_id), to: MonitorInstance

  defdelegate active_subscription_count(), to: Backend.Projections.Dbpa.Subscription
  defdelegate active_subscription_count(account_id), to: Backend.Projections.Dbpa.Subscription

  defdelegate active_notices_by_monitor_id(monitor_id), to: Backend.Projections.Notice
  defdelegate active_notices(), to: Backend.Projections.Notice

  # Status page stuff
  defdelegate status_pages, to: Backend.Projections.Dbpa.StatusPage
  def status_page_by_name(name), do: status_page_by_name(Domain.Helpers.shared_account_id(), name)
  defdelegate status_page_by_name(account_id, name), to: Backend.Projections.Dbpa.StatusPage
  defdelegate status_page_by_id(account_id, id), to: Backend.Projections.Dbpa.StatusPage

  def status_page_changes(monitor, timespan),
    do: status_page_changes(Domain.Helpers.shared_account_id(), monitor, timespan)

  defdelegate status_page_changes(account_id, monitor, timespan),
    to: Backend.Projections.Dbpa.StatusPage

  defdelegate status_page_status_to_snapshot_state(status),
    to: Backend.Projections.Dbpa.StatusPage

  def status_page_limit, do: Backend.Projections.Dbpa.StatusPage.limit()

  defdelegate alert_count(), to: Backend.Projections.Dbpa.Alert
  defdelegate get_alert_by_id(account_id, alert_id), to: Backend.Projections.Dbpa.Alert

  defdelegate alert_delivery_count(), to: Backend.Projections.Dbpa.AlertDelivery
  defdelegate subscription_delivery_count(), to: Backend.Projections.Dbpa.SubscriptionDelivery

  defdelegate subscription_deliveries_since(
                account_id,
                monitor_logical_name,
                hours,
                preloads \\ []
              ),
              to: Backend.Projections.Dbpa.SubscriptionDelivery

  defdelegate get_subscription_delivery(account_id, id, preloads \\ []),
    to: Backend.Projections.Dbpa.SubscriptionDelivery

  defdelegate get_subscriptions_for_account(account_id, preloads \\ []),
    to: Backend.Projections.Dbpa.Subscription

  defdelegate get_subscriptions_for_monitor(account_id, monitor_logical_name, preloads \\ []),
    to: Backend.Projections.Dbpa.Subscription

  defdelegate get_slack_subscriptions_for_account_and_identity(
                account_id,
                identity,
                preloads \\ []
              ),
              to: Backend.Projections.Dbpa.Subscription

  defdelegate get_slack_workspaces(account_id), to: Backend.Projections.SlackWorkspace
  defdelegate has_slack_workspaces?(account_id), to: Backend.Projections.SlackWorkspace

  defdelegate has_slack_token?(workspace_id), to: Backend.Projections.SlackWorkspace

  defdelegate get_slack_token(workspace_id), to: Backend.Projections.SlackWorkspace

  defdelegate get_microsoft_tenants(account_id), to: Backend.Projections.MicrosoftTenant
  defdelegate has_microsoft_tenants?(account_id), to: Backend.Projections.MicrosoftTenant

  defdelegate get_accounts_for_monitor(monitor_logical_name, opts \\ []), to: Backend.Projections.Account

  defdelegate get_accounts_with_subscription_to_monitor(monitor_logical_name),
    to: Backend.Projections.Account

  defdelegate monitor_errors(
                account_id,
                logical_name \\ nil,
                timespan,
                group_by_check \\ true,
                order_by_ascending \\ true
              ),
              to: Backend.Projections.Dbpa.MonitorError

  defdelegate monitor_errors_paged(
    account_id,
    logical_name,
    opts
  ),
  to: Backend.Projections.Dbpa.MonitorError

  defdelegate active_web_users(since), to: Backend.Projections.Aggregate.WebLoginAggregate

  defdelegate active_teams_users(since), to: Backend.Projections.Aggregate.AppUseAggregate
  defdelegate active_slack_users(since), to: Backend.Projections.Aggregate.AppUseAggregate

  defdelegate api_count(since), to: Backend.Projections.Aggregate.ApiUseAggregate
  defdelegate active_api_accounts(since), to: Backend.Projections.Aggregate.ApiUseAggregate

  defdelegate register_api_hit(account_id),
    to: Backend.Projections.Aggregate.ApiUseAggregate

  defdelegate telemetry(account_id, monitor_name, timespan),
    to: Backend.Projections.Telemetry.MonitorTelemetry

  defdelegate flow_stats(name, period), to: Backend.Projections.Aggregate.FlowAggregate

  defdelegate new_signups(since), to: Backend.Projections.Aggregate.NewSignupAggregate

  defdelegate outstanding_events(account_id), to: MonitorEvent
  defdelegate outstanding_events(account_id, logical_name), to: MonitorEvent

  defdelegate get_instances_for_monitors(account_id, monitor_logical_names), to: MonitorInstance
  defdelegate account_subscribed_to_status_page_component?(account_id, status_page_id, component_id), to: StatusPageSubscription

  defdelegate list_issues_paginated(account_id, params), to: Backend.Projections.Dbpa.Issue
  defdelegate list_issue_events_paginated(account_id, params), to: Backend.Projections.Dbpa.IssueEvent
  defdelegate services_impacted_count(account_id, issue_id), to: Backend.Projections.Dbpa.IssueEvent
end
