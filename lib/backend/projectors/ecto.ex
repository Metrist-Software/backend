defmodule Backend.Projectors.Ecto do
  use Commanded.Projections.Ecto,
    application: Backend.App,
    name: __MODULE__,
    repo: Backend.Repo,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  alias Domain.{User, Account, Monitor, StatusPage, Notice, Flow, Issue, DatadogGrants}

  alias Backend.Projections
  alias Backend.Projections.Dbpa.StatusPage.StatusPageComponent
  import Backend.Repo, only: [schema_name: 1]
  require Logger

  @impl true
  def error({:error, _error}, event, _failure_context) do
    Logger.error("ERROR: could not project event in Ecto: #{inspect event}")
    :skip
  end

  project(e = %User.Events.Created{}, _metadata, fn multi ->
    e = Domain.CryptUtils.decrypt(e)
    Ecto.Multi.insert(multi, :ecto_projector, %Projections.User{
      id: e.id,
      account_id: e.user_account_id,
      email: e.email,
      uid: e.uid,
      is_metrist_admin: false,
      is_read_only: e.is_read_only
    },
    on_conflict: :nothing)
  end)

  project(e = %Account.Events.Created{}, _metadata, fn multi ->
    e = Domain.CryptUtils.decrypt(e)
    Ecto.Multi.insert(multi, :ecto_projector, %Projections.Account{
      id: e.id,
      name: e.name,
      free_trial_end_time: NaiveDateTime.from_iso8601!(e.free_trial_end_time),
    },
    on_conflict: :nothing)
  end)

  project(e = %StatusPage.Events.ComponentAdded{}, _metadata, fn multi ->
    multi
    |> Ecto.Multi.run(:status_page_component, fn repo, _changes ->
      page_component =
        repo.get_by(StatusPageComponent, [id: Domain.StatusPage.component_id_of(e)], prefix: schema_name(e.account_id)) ||
          %StatusPageComponent{id: Domain.StatusPage.component_id_of(e)}

      {:ok, page_component}
    end)
    |> Ecto.Multi.insert_or_update(
      :update,
      &Ecto.Changeset.change(&1.status_page_component, %{
        status_page_id: e.id,
        name: e.name,
        recent_change_id: e.change_id
      }),
      prefix: schema_name(e.account_id)
    )
  end)

  project(e = %StatusPage.Events.ComponentRemoved{}, _metadata, fn multi ->
    # Note - this will not work on old components that don't have their component id set as Domain.Id.new() was used to generate the id
    # On rollout of the id fixes a Domain.StatusPage.Reset will be run and projection data nuked so this should be ok
    # If reprojected again the reset itself will remove everything through ComponentRemoved events but that won't work
    # the first time as the aggregate is out of sync with the DB (id's different etc.)
    component = StatusPageComponent
    |> Backend.Repo.get(Domain.StatusPage.component_id_of(e), prefix: schema_name(e.account_id))

    ecto_multi_try_delete(multi, :ecto_projector, component, prefix: schema_name(e.account_id))
  end)

  project(e = %Account.Events.NameUpdated{}, _metadata, fn multi ->
    e = Domain.CryptUtils.decrypt(e)
    change =
      Projections.Account
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(name: e.name)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.FreeTrialUpdated{}, _metadata, fn multi ->
    change =
      Projections.Account
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(free_trial_end_time: NaiveDateTime.from_iso8601!(e.free_trial_end_time))

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.MonitorAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.Monitor{
        logical_name: e.logical_name,
        name: e.name
      },
      prefix: schema_name(e.id),
      on_conflict: :replace_all,
      conflict_target: :logical_name
    )
  end)

  project(e = %Account.Events.MonitorRemoved{}, _metadata, fn multi ->
    monitor = Projections.Dbpa.Monitor
      |> Backend.Repo.get(e.logical_name, prefix: schema_name(e.id))

    ecto_multi_try_delete(multi, :ecto_projector, monitor, prefix: schema_name(e.id))
  end)

  project(e = %Account.Events.InstancesAdded{}, _metadata, fn multi ->
    entries = Enum.map(e.instances, fn m -> timestamps(name: m) end)

    Ecto.Multi.insert_all(multi, :ecto_projector, Projections.Dbpa.Instance, entries,
      prefix: schema_name(e.id),
      on_conflict: :nothing
    )
  end)

  project(e = %Account.Events.InstanceAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.Instance{
        name: e.instance_name
      },
      prefix: schema_name(e.id),
      on_conflict: :nothing,
      conflict_target: [:name]
    )
  end)

  project(e = %Account.Events.InstanceRemoved{}, _metadata, fn multi ->
    query = from i in Projections.Dbpa.Instance, where: i.name == ^e.instance_name
    Ecto.Multi.delete_all(
      multi,
      :ecto_projector,
      query,
      prefix: schema_name(e.id)
    )
  end)

  project(%User.Events.Updated{id: "ADMIN"}, _metadata, fn multi ->
    Logger.info("(Bootstrap) not updating ADMIN user")
    multi
  end)
  project(e = %User.Events.Updated{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(account_id: e.user_account_id)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(%User.Events.AccountIdUpdate{id: "ADMIN"}, _metadata, fn multi ->
    Logger.info("(Bootstrap) not updating ADMIN user")
    multi
  end)
  project(e = %User.Events.AccountIdUpdate{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(account_id: e.user_account_id)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.LoggedIn{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(last_login: e.timestamp)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.InviteCreated{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.Invite{
        id: e.invite_id,
        invitee_id: e.id,
        inviter_id: e.inviter_id
      },
      prefix: schema_name(e.account_id),
      on_conflict: :nothing
    )
  end)

  project(e = %User.Events.InviteDeleted{}, _metadata, fn multi ->
    invite = Projections.Dbpa.Invite
      |> Backend.Repo.get(e.invite_id, prefix: schema_name(e.account_id))

    ecto_multi_try_delete(multi, :ecto_projector, invite, prefix: schema_name(e.account_id))
  end)

  project(e = %User.Events.InviteAccepted{}, metadata, fn multi ->
    accepted_at = dt_with_default_from_meta(e.accepted_at, metadata)
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(account_id: e.account_id)

    invite = Projections.Dbpa.Invite
    |> Backend.Repo.get(e.invite_id, prefix: schema_name(e.account_id))
    |> Ecto.Changeset.change(accepted_at: accepted_at)

    multi
    |> Ecto.Multi.update(:update_user, change)
    |> Ecto.Multi.update(:update_invite, invite)
  end)

  project(e = %Account.Events.SlackWorkspaceAttached{}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :ecto_projector, %Projections.SlackWorkspace{
      id: e.team_id,
      account_id: e.id,
      team_name: e.team_name,
      scope: e.scope,
      bot_user_id: e.bot_user_id,
      access_token: e.access_token
    },
    on_conflict: :replace_all,
    conflict_target: [:id] )
  end)

  project(e = %Account.Events.SlackWorkspaceRemoved{}, _metadata, fn multi ->
    workspace = Projections.SlackWorkspace
      |> Backend.Repo.get(e.team_id)

    ecto_multi_try_delete(multi, :ecto_projector, workspace)
  end)

  project(e = %Account.Events.MicrosoftTenantAttached{}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :ecto_projector, %Projections.MicrosoftTenant{
      id: e.tenant_id,
      account_id: e.id,
      name: e.name,
      team_id: e.team_id,
      team_name: e.team_name,
      service_url: e.service_url
    },
    on_conflict: :nothing)
  end)

  project(e = %Account.Events.MicrosoftTenantUpdated{}, _metadata, fn multi ->
    change = Projections.MicrosoftTenant
      |> Backend.Repo.get(e.tenant_id)
      |> Ecto.Changeset.change(
        team_id: e.team_id,
        team_name: e.team_name,
        service_url: e.service_url
      )

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.MadeInternal{}, _metadata, fn multi ->
    change =
      Projections.Account
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(is_internal: true)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.MadeExternal{}, _metadata, fn multi ->
    change =
      Projections.Account
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(is_internal: false)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.MadeAdmin{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(is_metrist_admin: true)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.RepealedAdmin{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(is_metrist_admin: false)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.ReadOnlySet{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(is_read_only: e.is_read_only)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.APITokenAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Backend.Projections.APIToken{
        api_token: e.api_token,
        account_id: e.id
      },
      on_conflict: :replace_all,
      conflict_target: :api_token
    )
  end)

  project(e = %Account.Events.APITokenRemoved{}, _metadata, fn multi ->
    token = Backend.Repo.get(Projections.APIToken, e.api_token)

    ecto_multi_try_delete(multi, :ecto_projector, token)
  end)

  project(e = %Account.Events.SlackSlashCommandAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :ecto_projector, %Backend.Projections.SlackSlashCommand{
      id: Domain.Account.id_of(e),
      data: e.data
    },
    on_conflict: :nothing)
  end)

  project(e = %Account.Events.MicrosoftTeamsCommandAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :ecto_projector, %Backend.Projections.MicrosoftTeamsCommand{
      id: Domain.Account.id_of(e),
      data: e.data
    },
    on_conflict: :nothing)
  end)

  project(e = %Account.Events.SubscriptionAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.Subscription{
        id: e.subscription_id,
        monitor_id: e.monitor_id,
        delivery_method: e.delivery_method,
        identity: e.identity,
        regions: e.regions,
        extra_config: e.extra_config,
        display_name: e.display_name
      },
      prefix: schema_name(e.id),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:id]
    )
  end)

  project(e = %Account.Events.SubscriptionDeliveryAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.SubscriptionDelivery{
        id: e.subscription_delivery_id,
        monitor_logical_name: e.monitor_logical_name,
        alert_id: e.alert_id,
        subscription_id: e.subscription_id,
        result: e.result,
        status_code: e.status_code,
        delivery_method: e.delivery_method,
        display_name: e.display_name
      },
      prefix: schema_name(e.id),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:id]
    )
  end)

  project(e = %Account.Events.SubscriptionDeliveryAddedV2{}, _metadata, fn multi ->
    subscription =
      Projections.Dbpa.Subscription
      |> Backend.Repo.get(e.subscription_id, prefix: schema_name(e.id))

    alert =
      Projections.Dbpa.Alert
      |> Backend.Repo.get(e.alert_id, prefix: schema_name(e.id))

    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.SubscriptionDelivery{
        id: e.subscription_delivery_id,
        monitor_logical_name: alert.monitor_logical_name,
        alert_id: e.alert_id,
        subscription_id: e.subscription_id,
        result: nil,
        status_code: e.status_code,
        delivery_method: subscription.delivery_method,
        display_name: Backend.Projections.Dbpa.Subscription.safe_display_name(subscription)
      },
      prefix: schema_name(e.id),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:id]
    )
  end)

  project(e = %Account.Events.SubscriptionDeleted{}, _metadata, fn multi ->
    subscription = Projections.Dbpa.Subscription
      |> Backend.Repo.get(e.subscription_id, prefix: schema_name(e.id))

    ecto_multi_try_delete(multi, :ecto_projector, subscription, prefix: schema_name(e.id))
  end)

  project(e = %Account.Events.StripeCustomerIdSet{}, _metadata, fn multi ->
    change = Projections.Account
    |> Backend.Repo.get(e.id)
    |> Ecto.Changeset.change(stripe_customer_id: e.customer_id)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.MembershipCreated{}, _metadata, fn multi ->
    start_date = e.start_date
    |> NaiveDateTime.from_iso8601!()
    |> NaiveDateTime.truncate(:second)

    multi
    |> Ecto.Multi.delete_all(
        :end_active_memberships,
        Projections.Membership.active_memberships_query(e.id))
    |> Ecto.Multi.insert(
        :ecto_projector,
        %Projections.Membership{
          id: e.membership_id,
          account_id: e.id,
          tier: String.to_atom(e.tier),
          billing_period: String.to_atom(e.billing_period),
          start_date: start_date,
          end_date: nil
        },
        on_conflict: :nothing)
  end)

  project(%Account.Events.MembershipIntentStarted{}, _metadata, fn multi ->
    multi
  end)

  project(e = %Monitor.Events.CheckAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.MonitorCheck{
        logical_name: e.logical_name,
        monitor_logical_name: e.monitor_logical_name,
        name: e.name,
        is_private: e.is_private
      },
      prefix: schema_name(e.account_id),
      on_conflict: :replace_all,
      conflict_target: [:logical_name, :monitor_logical_name]
    )
  end)

  project(e = %Monitor.Events.CheckNameUpdated{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.MonitorCheck
      |> Backend.Repo.get_by(
        [monitor_logical_name: e.monitor_logical_name, logical_name: e.logical_name],
        prefix: schema_name(e.account_id)
      )
      |> Ecto.Changeset.change(name: e.name)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)


  project(e = %Monitor.Events.CheckRemoved{}, _metadata, fn multi ->
    check = Projections.Dbpa.MonitorCheck
      |> Backend.Repo.get_by([logical_name: e.check_logical_name, monitor_logical_name: e.monitor_logical_name], prefix: schema_name(e.account_id))

    ecto_multi_try_delete(multi, :ecto_projector, check, prefix: schema_name(e.account_id))
  end)

  # There's a bad event in the event store "0f51959f-7129-401f-9aa0-eaf77cb3a7e9" that managed to fire an
  # Command.AddConfig before the monitor was created. This caused the account_id of the ConfigAdded event to be nil
  # We can't remove it because the RemoveConfig command automatically applies the account_id from the monitor
  # and the event ran on the 11yHN8oQf2CCDHm14AQgMdq_slack aggregate (which has a different account id)
  # Ignore ConfigAdded events with no account ID so the bad config doesn't show up again if we replay
  project(%Monitor.Events.ConfigAdded{account_id: nil}, _metadata, fn multi ->
    multi
  end)

  project(e = %Monitor.Events.ConfigAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.MonitorConfig{
        id: Domain.Monitor.config_id_of(e),
        monitor_logical_name: e.monitor_logical_name,
        interval_secs: e.interval_secs,
        extra_config: e.extra_config,
        run_groups: e.run_groups,
        run_spec: e.run_spec,
        steps: e.steps
      },
      prefix: schema_name(e.account_id),
      on_conflict: :replace_all,
      conflict_target: [:id]
    )
  end)

  project(e = %Monitor.Events.RunGroupsSet{}, _metadata, fn multi ->
    cfg =
      Projections.Dbpa.MonitorConfig
      |> Backend.Repo.get(
        Domain.Monitor.config_id_of(e),
        prefix: schema_name(e.account_id)
      )
    change = Ecto.Changeset.change(cfg, run_groups: e.run_groups)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.RunSpecSet{}, _metadata, fn multi ->
    cfg =
      Projections.Dbpa.MonitorConfig
      |> Backend.Repo.get(
        e.config_id,
        prefix: schema_name(e.account_id)
      )
    change = Ecto.Changeset.change(cfg, run_spec: e.run_spec)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.StepsSet{}, _metadata, fn multi ->
    cfg =
      Projections.Dbpa.MonitorConfig
      |> Backend.Repo.get(
        e.config_id,
        prefix: schema_name(e.account_id)
      )
    change = Ecto.Changeset.change(cfg, steps: e.steps)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.IntervalSecsSet{}, _metadata, fn multi ->
    cfg =
      Projections.Dbpa.MonitorConfig
      |> Backend.Repo.get(
        e.config_id,
        prefix: schema_name(e.account_id)
      )
    change = Ecto.Changeset.change(cfg, interval_secs: e.interval_secs)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.ExtraConfigSet{}, _metadata, fn multi ->
    cfg =
      Projections.Dbpa.MonitorConfig
      |> Backend.Repo.get(
        Domain.Monitor.config_id_of(e),
        prefix: schema_name(e.account_id)
      )
    extra_config = case cfg.extra_config do
                     nil -> Map.put(%{}, e.key, e.value)
                     ec -> Map.put(ec, e.key, e.value)
                   end
    change = Ecto.Changeset.change(cfg, extra_config: extra_config)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.ConfigRemoved{}, _metadata, fn multi ->
    config = Projections.Dbpa.MonitorConfig
      |> Backend.Repo.get(e.monitor_config_id, prefix: schema_name(e.account_id))

    ecto_multi_try_delete(multi, :ecto_projector, config, prefix: schema_name(e.account_id))
  end)

  project(e = %Monitor.Events.AnalyzerConfigAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      Projections.Dbpa.AnalyzerConfig.from_event(e),
      prefix: schema_name(e.account_id),
      on_conflict: :replace_all,
      conflict_target: :monitor_logical_name
    )
  end)

  project(e = %Monitor.Events.AnalyzerConfigUpdated{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.AnalyzerConfig
      |> Backend.Repo.get_by(
        [monitor_logical_name: e.monitor_logical_name],
        prefix: schema_name(e.account_id)
      )
      |> Ecto.Changeset.change(
          default_degraded_threshold: e.default_degraded_threshold,
          default_degraded_down_count: e.default_degraded_down_count,
          default_degraded_up_count: e.default_degraded_up_count,
          default_degraded_timeout: e.default_degraded_timeout,
          default_error_timeout: e.default_error_timeout,
          default_error_down_count: e.default_error_down_count,
          default_error_up_count: e.default_error_up_count,
          instances: e.instances,
          check_configs: e.check_configs)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.AnalyzerConfigRemoved{}, _metadata, fn multi ->
    analyzer_config =
      Projections.Dbpa.AnalyzerConfig
      |> Backend.Repo.get_by(
        [monitor_logical_name: e.monitor_logical_name],
        prefix: schema_name(e.account_id)
      )

    ecto_multi_try_delete(multi, :ecto_projector, analyzer_config, prefix: schema_name(e.account_id))
  end)

  project(e = %Monitor.Events.ErrorAdded{}, _metadata, fn multi ->
    result = Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.MonitorError{
        id: Domain.Monitor.error_id_of(e),
        monitor_logical_name: e.monitor_logical_name,
        check_logical_name: e.check_logical_name,
        instance_name: e.instance_name,
        message: e.message,
        time: e.time,
        blocked_steps: e.blocked_steps,
        is_valid: true
      },
      prefix: schema_name(e.account_id),
      on_conflict: :nothing
    )

    # This is as good a spot as anything to send the error off to
    # the monitor age process.
    Backend.MonitorAgeTelemetry.process_error(e)

    result
  end)

  project(e = %Monitor.Events.EventAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.MonitorEvent{
        id: Domain.Monitor.event_id_of(e),
        monitor_logical_name: e.monitor_logical_name,
        check_logical_name: e.check_logical_name,
        instance_name: e.instance_name,
        state: String.to_atom(e.state),
        message: e.message,
        start_time: e.start_time,
        end_time: e.end_time,
        correlation_id: e.correlation_id,
        is_valid: true
      },
      prefix: schema_name(e.account_id),
      on_conflict: :nothing
    )
  end)

  project(e = %Monitor.Events.InstanceAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.MonitorInstance{
        monitor_logical_name: e.monitor_logical_name,
        instance_name: e.instance_name,
        last_report: e.last_report,
        check_last_reports: e.check_last_reports
      },
      prefix: schema_name(e.account_id),
      on_conflict: :replace_all,
      conflict_target: [:monitor_logical_name, :instance_name]
    )
  end)

  project(e = %Monitor.Events.InstanceUpdated{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.MonitorInstance
      |> Backend.Repo.get_by(
        [monitor_logical_name: e.monitor_logical_name, instance_name: e.instance_name],
        prefix: schema_name(e.account_id)
      )
      |> Ecto.Changeset.change(last_report: e.last_report)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.InstanceRemoved{}, _metadata, fn multi ->
    instance =
      Projections.Dbpa.MonitorInstance
      |> Backend.Repo.get_by(
        [monitor_logical_name: e.monitor_logical_name, instance_name: e.instance_name],
        prefix: schema_name(e.account_id)
      )

    ecto_multi_try_delete(multi, :ecto_projector, instance, prefix: schema_name(e.account_id))
  end)

  project(e = %Monitor.Events.InstanceCheckUpdated{}, _metadata, fn multi ->
    monitor_instance =
      Projections.Dbpa.MonitorInstance
      |> Backend.Repo.get_by(
        [monitor_logical_name: e.monitor_logical_name, instance_name: e.instance_name],
        prefix: schema_name(e.account_id)
      )
    updated_checks = Map.put(monitor_instance.check_last_reports, e.check_logical_name, e.last_report)
    change = monitor_instance
    |> Ecto.Changeset.change(check_last_reports: updated_checks)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.EventEnded{}, metadata, fn multi ->
    end_time = dt_with_default_from_meta(e.end_time, metadata)
    change =
      Projections.Dbpa.MonitorEvent
      |> Backend.Repo.get(e.monitor_event_id, prefix: schema_name(e.account_id))
      |> Ecto.Changeset.change(end_time: end_time)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.EventsCleared{}, metadata, fn multi ->
    end_time = dt_with_default_from_meta(e.end_time, metadata)
    query =
      from(
        me in Projections.Dbpa.MonitorEvent,
        where: me.monitor_logical_name == ^e.monitor_logical_name and is_nil(me.end_time)
      )

    Ecto.Multi.update_all(
      multi,
      :ecto_projector,
      query,
      [set: [end_time: end_time]],
      prefix: schema_name(e.account_id)
    )
  end)


  project(e = %Monitor.Events.EventsInvalidated{}, _metadata, fn multi ->
    query =
      from(
        me in Projections.Dbpa.MonitorEvent,
        where: me.monitor_logical_name == ^e.logical_name and me.check_logical_name == ^e.check_logical_name
        and ^e.end_time >= me.end_time and ^e.start_time <= me.end_time
      )

    Ecto.Multi.update_all(
      multi,
      :ecto_projector,
      query,
      [set: [is_valid: :false]],
      prefix: schema_name(e.account_id)
    )
  end)


  project(e = %Monitor.Events.ErrorsInvalidated{}, _metadata, fn multi ->
    query =
      from(
        me in Projections.Dbpa.MonitorError,
        where: me.monitor_logical_name == ^e.logical_name and me.check_logical_name == ^e.check_logical_name
        and ^e.end_time >= me.time and ^e.start_time <= me.time
      )

    Ecto.Multi.update_all(
      multi,
      :ecto_projector,
      query,
      [set: [is_valid: :false]],
      prefix: schema_name(e.account_id)
    )
  end)


  project(e = %Monitor.Events.TagAdded{}, _metadata, fn multi ->
    multi
      |> Ecto.Multi.run(:monitor_tags, fn repo, _changes ->
        monitor_tags = repo.get(Projections.Dbpa.MonitorTags, e.monitor_logical_name, prefix: schema_name(e.account_id))
          || %Projections.Dbpa.MonitorTags{monitor_logical_name: e.monitor_logical_name, tags: []}
        {:ok, monitor_tags}
      end)
      |> Ecto.Multi.insert_or_update(
        :update,
        &Ecto.Changeset.change(&1.monitor_tags, tags: [e.tag | &1.monitor_tags.tags]),
        prefix: schema_name(e.account_id))
  end)

  project(e = %Monitor.Events.TagRemoved{}, _metadata, fn multi ->
    multi
      |> Ecto.Multi.run(:monitor_tags, fn repo, _changes ->
        monitor_tags = repo.get(Projections.Dbpa.MonitorTags, e.monitor_logical_name, prefix: schema_name(e.account_id))
          || %Projections.Dbpa.MonitorTags{monitor_logical_name: e.monitor_logical_name, tags: []}
        {:ok, monitor_tags}
      end)
      |> Ecto.Multi.insert_or_update(
        :update,
        &Ecto.Changeset.change(&1.monitor_tags, tags: List.delete(&1.monitor_tags.tags, e.tag)),
        prefix: schema_name(e.account_id))
  end)

  project(e = %Monitor.Events.TagChanged{}, _metadata, fn multi ->
    multi
      |> Ecto.Multi.run(:monitor_tags, fn repo, _changes ->
        monitor_tags = repo.get(Projections.Dbpa.MonitorTags, e.monitor_logical_name, prefix: schema_name(e.account_id))
          || %Projections.Dbpa.MonitorTags{monitor_logical_name: e.monitor_logical_name, tags: []}
        {:ok, monitor_tags}
      end)
      |> Ecto.Multi.insert_or_update(
        :update,
        &Ecto.Changeset.change(&1.monitor_tags, tags: [e.to_tag | List.delete(&1.monitor_tags.tags, e.from_tag)]),
        prefix: schema_name(e.account_id))
  end)

  project(e = %Monitor.Events.NameChanged{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.Monitor
      |> Backend.Repo.get_by([logical_name: e.monitor_logical_name],
                             prefix: schema_name(e.account_id))
      |> Ecto.Changeset.change(name: e.name)
    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Monitor.Events.TwitterHashtagsSet{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.MonitorTwitterInfo{
        monitor_logical_name: e.monitor_logical_name,
        hashtags: e.hashtags
      },
      prefix: schema_name(e.account_id),
      on_conflict: {:replace, [:hashtags]},
      conflict_target: :monitor_logical_name
    )
  end)

  project(e = %Monitor.Events.TwitterCountAdded{}, _metadata, fn multi ->
    # As we add stuff, we also delete older stuff - we only need it currently for
    # the 24 hour lookback so that is where we truncate the table.
    max_lookback = NaiveDateTime.utc_now() |> NaiveDateTime.add(-86_400, :second)
    multi
    |> Ecto.Multi.insert(
      :count_insert,
      %Projections.Dbpa.MonitorTwitterCounts{
        monitor_logical_name: e.monitor_logical_name,
        hashtag: e.hashtag,
        bucket_end_time: e.bucket_end_time,
        bucket_duration: e.bucket_duration,
        count: e.count
      },
      prefix: schema_name(e.account_id))
    |> Ecto.Multi.delete_all(
      :count_cleanup,
      from(c in Projections.Dbpa.MonitorTwitterCounts,
        where: c.bucket_end_time < ^max_lookback),
      prefix: schema_name(e.account_id)
    )
  end)

  project(e = %StatusPage.Events.Removed{}, _metadata, fn multi ->
    # For now, we only have shared status pages.
    account_id = Domain.Helpers.shared_account_id()
    subscription_query = from s in Projections.Dbpa.StatusPage.StatusPageSubscription , where: s.status_page_id == ^e.id
    component_changes_query = from s in Projections.Dbpa.StatusPage.ComponentChange , where: s.status_page_id == ^e.id
    component_query = from c in Projections.Dbpa.StatusPage.StatusPageComponent, where: c.status_page_id == ^e.id
    page_query = from sp in Projections.Dbpa.StatusPage, where: sp.id == ^e.id
    multi |>
    Ecto.Multi.delete_all(
      :subscription_projector,
      subscription_query,
      prefix: schema_name(account_id)
    ) |>
    Ecto.Multi.delete_all(
      :component_changes_projector,
      component_changes_query,
      prefix: schema_name(account_id)
    ) |>
    Ecto.Multi.delete_all(
      :component_projector,
      component_query,
      prefix: schema_name(account_id)
    ) |>
    Ecto.Multi.delete_all(
      :page_projector,
      page_query,
      prefix: schema_name(account_id)
    )
  end)

  project(e = %StatusPage.Events.Created{}, _metadata, fn multi ->
    # For now, we only have shared status pages.
    account_id = Domain.Helpers.shared_account_id()
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.StatusPage{
        id: e.id,
        name: e.page
      },
      prefix: schema_name(account_id),
      on_conflict: :nothing)
  end)

  project(e = %StatusPage.Events.ComponentStatusChanged{}, _metadata, fn multi ->
    account_id = Domain.Helpers.shared_account_id()

    component = Backend.Repo.get_by(StatusPageComponent, [id: Domain.StatusPage.component_id_of(e)], prefix: schema_name(account_id))

    multi = Ecto.Multi.insert(
      multi,
      :ecto_projector,
      Projections.Dbpa.StatusPage.ComponentChange.from_event(e),
      prefix: schema_name(account_id),
      on_conflict: :nothing)

    if component do
      change = Ecto.Changeset.change(component, recent_change_id: e.change_id)
      Ecto.Multi.update(multi, :component_update, change)
    else
      multi
    end

  end)

  project(e = %StatusPage.Events.SubscriptionAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.StatusPage.StatusPageSubscription{
        id: e.subscription_id,
        status_page_id: e.id,
        component_id: e.component_id
      },
      prefix: schema_name(e.account_id),
      on_conflict: :raise
    )
  end)

  project(e = %StatusPage.Events.SubscriptionRemoved{}, _metadata, fn multi ->
    query = from sub in Projections.Dbpa.StatusPage.StatusPageSubscription,
      where: sub.id == ^e.subscription_id
    Ecto.Multi.delete_all(
      multi,
      :ecto_projector,
      query,
      prefix: schema_name(e.account_id)
    )
  end)

  project(e = %StatusPage.Events.ComponentChangeRemoved{}, _metadata, fn multi ->
    account_id = Domain.Helpers.shared_account_id()

    component_change = Projections.Dbpa.StatusPage.ComponentChange
    |> Backend.Repo.get(e.change_id, prefix: schema_name(account_id))

    ecto_multi_try_delete(multi, :ecto_projector, component_change, prefix: schema_name(account_id))
  end)

  project(e = %Notice.Events.Created{}, _metadata, fn multi ->
    end_date = if e.end_date == nil do
      nil
    else
      e.end_date
      |> NaiveDateTime.from_iso8601!()
      |> NaiveDateTime.truncate(:second)
    end

    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Notice{
        id: e.id,
        monitor_id: e.monitor_id,
        summary: e.summary,
        description: e.description,
        end_date: end_date
      },
      on_conflict: :nothing)
  end)

  project(e = %Notice.Events.ContentUpdated{}, _metadata, fn multi ->
    change =
      Projections.Notice
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(summary: e.summary, description: e.description)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Notice.Events.EndDateUpdated{}, _metadata, fn multi ->
    end_date = if e.end_date == nil do
      nil
    else
      e.end_date
      |> NaiveDateTime.from_iso8601!()
      |> NaiveDateTime.truncate(:second)
    end

    change =
      Projections.Notice
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(end_date: end_date)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Notice.Events.MarkedRead{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.NoticeRead{
        notice_id: e.id,
        user_id: e.user_id,
      },
      on_conflict: :nothing)
  end)

  project(e = %Account.Events.AlertAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.Alert{
        id: e.alert_id,
        monitor_logical_name: e.monitor_logical_name,
        state: String.to_atom(e.state),
        is_instance_specific: e.is_instance_specific,
        subscription_id: e.subscription_id,
        formatted_messages: e.formatted_messages,
        affected_regions: e.affected_regions,
        affected_checks: e.affected_checks,
        generated_at: e.generated_at,
        correlation_id: e.correlation_id,
        monitor_name: e.monitor_name
      },
      prefix: schema_name(e.id),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:id]
    )
  end)

  project(e = %Account.Events.AlertDeliveryAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.AlertDelivery{
        id: e.alert_delivery_id,
        alert_id: e.alert_id,
        delivery_method: e.delivery_method,
        delivered_by_region: e.delivered_by_region,
        started_at: e.started_at,
        completed_at: e.completed_at,
      },
      prefix: schema_name(e.id),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:id]
    )
  end)

  project(e = %User.Events.HubspotContactCreated{}, _metadata, fn multi ->
     change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(hubspot_contact_id: e.contact_id)


    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.TimezoneUpdated{}, _metadata, fn multi ->
     change =
      %Projections.User{id: e.id}
      |> Ecto.Changeset.change(timezone: e.timezone)


    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.AlertDeliveryCompleted{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.AlertDelivery
      |> Backend.Repo.get(e.alert_delivery_id, prefix: schema_name(e.id))
      |> Ecto.Changeset.change(completed_at: e.completed_at)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.Auth0InfoUpdated{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(uid: e.uid)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %User.Events.SlackDetailsUpdated{}, _metadata, fn multi ->
    change =
      Projections.User
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.change(last_seen_slack_team_id: e.last_seen_slack_team_id, last_seen_slack_user_id: e.last_seen_slack_user_id)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %Account.Events.VisibleMonitorAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.VisibleMonitor{
        monitor_logical_name: e.monitor_logical_name,
      },
      prefix: schema_name(e.id),
      on_conflict: :nothing,
      conflict_target: [:monitor_logical_name]
    )
  end)

  project(e = %Account.Events.VisibleMonitorRemoved{}, _metadata, fn multi ->
    query = from v in Projections.Dbpa.VisibleMonitor, where: v.monitor_logical_name == ^e.monitor_logical_name
    Ecto.Multi.delete_all(
      multi,
      :ecto_projector,
      query,
      prefix: schema_name(e.id)
    )
  end)

  project(e = %Account.Events.UserAdded{}, _metadata, fn multi ->
    account = Backend.Projections.Account.get_account(e.id)

    if is_nil(account.original_user_id) do
      change = Ecto.Changeset.change(account, original_user_id: e.user_id)
      Ecto.Multi.update(multi, :ecto_projector, change)
    else
      multi
    end
  end)

  project(e = %Issue.Events.IssueCreated{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.Issue{
        id: e.issue_id,
        worst_state: String.to_existing_atom(e.state),
        sources: [String.to_existing_atom(e.source)],
        service: e.service,
        start_time: e.start_time,
      },
      prefix: schema_name(e.account_id),
      on_conflict: :nothing
    )
  end)

  project(e = %Issue.Events.IssueEventAdded{}, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %Projections.Dbpa.IssueEvent{
        id: e.issue_event_id,
        issue_id: e.issue_id,
        state: String.to_existing_atom(e.state),
        source: String.to_existing_atom(e.source),
        source_id: e.source_id,
        region: e.region,
        check_logical_name: e.check_logical_name,
        component_id: e.component_id,
        start_time: e.start_time,
      },
      prefix: schema_name(e.account_id),
      on_conflict: :nothing
    )
  end)

  project(e = %Issue.Events.IssueStateChanged{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.Issue
      |> Backend.Repo.get(e.issue_id, prefix: schema_name(e.account_id))
      |> Ecto.Changeset.change(worst_state: String.to_existing_atom(e.worst_state))

    Ecto.Multi.update(multi, :ecto_projector, change, prefix: schema_name(e.account_id))
  end)

  project(e = %Issue.Events.DistinctSourcesSet{}, _metadata, fn multi ->
    change = Projections.Dbpa.Issue
    |> Backend.Repo.get(e.issue_id, prefix: schema_name(e.account_id))
    |> Ecto.Changeset.change(sources: Enum.map(e.sources, &String.to_existing_atom/1))

    Ecto.Multi.update(multi, :ecto_projector, change, prefix: schema_name(e.account_id))
  end)

  project(e = %Issue.Events.IssueEnded{}, _metadata, fn multi ->
    change =
      Projections.Dbpa.Issue
      |> Backend.Repo.get(e.issue_id, prefix: schema_name(e.account_id))
      |> Ecto.Changeset.change(end_time: e.end_time)

    Ecto.Multi.update(multi, :ecto_projector, change, prefix: schema_name(e.account_id))
  end)

  project(e = %User.Events.EmailUpdated{}, _metadata, fn multi ->
    e = Domain.CryptUtils.decrypt(e)

    change =
     %Projections.User{id: e.id}
     |> Ecto.Changeset.change(email: e.email)


   Ecto.Multi.update(multi, :ecto_projector, change)
  end)

  project(e = %DatadogGrants.Events.GrantRequested{}, _metadata, fn multi ->
    case Backend.Repo.get(Backend.Datadog.AccessGrants, e.id) do
      grant when grant != nil ->
        change = Ecto.Changeset.change(grant, verifier: e.verifier)
        Ecto.Multi.update(multi, :ecto_projector, change)
      nil ->
        change = %Backend.Datadog.AccessGrants{id: e.id, user_id: e.user_id, verifier: e.verifier}
        Ecto.Multi.insert(multi, :ecto_projector, change)
    end
  end)

  project(e = %DatadogGrants.Events.GrantUpdated{}, _metadata, fn multi ->
    params = Map.from_struct(e)
      |> Map.put(:expires_at, DateTime.utc_now() |> DateTime.add(e.expires_in))

    change =
      Backend.Datadog.AccessGrants
      |> Backend.Repo.get(e.id)
      |> Ecto.Changeset.cast(
        params,
        [:access_token, :refresh_token, :scope, :expires_in, :expires_at]
      )

    Ecto.Multi.update(multi, :ecto_projector, change)
  end)


  # Flow projections, delegated to the projection's module as this file is getting too big.

  project(e = %Flow.Events.Created{}, _metadata, fn multi ->
    Projections.Aggregate.FlowAggregate.project(multi, e)
  end)

  project(e = %Flow.Events.StepCompleted{}, _metadata, fn multi ->
    Projections.Aggregate.FlowAggregate.project(multi, e)
  end)

  project(%Flow.Events.FlowCompleted{}, _metadata, fn multi ->
    multi
  end)

  project(%Flow.Events.FlowTimedOut{}, _metadata, fn multi ->
    multi
  end)

  project(%Domain.Clock.Ticked{}, _metadata, fn multi ->
    multi
  end)

  project(%Domain.Monitor.Events.TelemetryAdded{}, _metadata, fn multi ->
    multi
  end)

  project(%Domain.Account.Events.AlertDispatched{}, _metadata, fn multi ->
    multi
  end)

  project(%Domain.Account.Events.AlertDropped{}, _metadata, fn multi ->
    multi
  end)

  project(%Monitor.Events.MonitorToggledEvent{}, _metadata, fn multi ->
    # Deprecated
    multi
  end)

  project(%Domain.User.Events.DatadogLoggedIn{}, _metadata, fn multi ->
    multi
  end)

  project(e, _metadata, fn multi ->
    # This both logs what we're not handling and ensures we get the
    # after_update call for _every_ event, whether we want to stash it
    # in a database or not.
    Logger.info("Unhandled event in Ecto projection: #{inspect(e)}")
    multi
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%Domain.Monitor.Events.TelemetryAdded{}, _metadata, _changeset) do
    :ok
  end

  def after_update(%Monitor.Events.MonitorToggledEvent{}, _metadata, _changeset) do
    :ok
  end

  def after_update(event, metadata, _changeset) do
    Logger.debug("Broadcast after update: #{inspect(event)}")

    Backend.PubSub.broadcast_to_topic_of!(
      event,
      %{event: event, metadata: metadata}
    )
  end


  @doc """
  We have events that had improper date/time handling in that they got stored without
  "business-logic relevant" timestamps (as compared to inserted_at/updated_at which are
  purely informal). That got fixed by adding dt fields to commands and events where needed,
  but for replay, we will see nil values for the old events of course. In that case, we pluck
  the "created_at" from the metadata field which should be close enough to what would have been
  set back then.
  """
  def dt_with_default_from_meta(nil, %{created_at: meta_created_at}), do: DateTime.to_naive(meta_created_at)
  def dt_with_default_from_meta(dt, _), do: dt

  defp timestamps(kwl) do
    # Ecto insert_all does not autogenerate timestamps.
    ts = NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second) # Ecto expects NaiveDateTimes to have empty milli/microseconds
    kwl ++ [updated_at: ts, inserted_at: ts]
  end

  defp ecto_multi_try_delete(multi, name, item, opts \\ [])
  defp ecto_multi_try_delete(multi, _name, nil, _opts), do: multi
  defp ecto_multi_try_delete(multi, name, item, opts) do
    Ecto.Multi.delete(multi, name, item, opts)
  end
end
