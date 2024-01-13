defmodule Domain.Account do
  @derive Jason.Encoder
  require Logger

  defstruct [
    :id,
    :name,
    :is_internal,
    :stripe_customer_id,
    :membership_id,
    :membership_intent,
    api_tokens: [],
    monitors: [],
    instances: [],
    slack_workspaces: [],
    slack_slash_commands: [],
    microsoft_tenants: [],
    microsoft_teams_commands: [],
    subscriptions: [],
    alert_ids: [],
    alert_delivery_ids: [],
    visible_monitors: [],
    user_ids: []
  ]

  defmodule Monitor do
    # We don't need all of the data that is defined in Domain.Monitor, so another struct will do.
    # There's a latent issue here: the struct will be deserialized as a map with snapshotting. So
    # once we start doing logical name updates, we probably want the same kind of snapshot
    # serializatio as Domain.Monitor. For now, it's not an issue and bumping account serialization
    # is simple enough once we need it.
    @derive Jason.Encoder
    defstruct [:logical_name]
  end

  defmodule Subscription do
    @derive Jason.Encoder
    defstruct [
      :id,
      :delivery_method,
      :monitor_logical_name,
      slack_workspace_id: nil
    ]
  end

  alias Commanded.Aggregate.Multi
  alias __MODULE__.Commands
  alias __MODULE__.Events
  import Domain.Helpers

  # Command handling

  def execute(account = %__MODULE__{id: nil}, c = %Commands.Create{}) do
    # TODO: Move to db_creator event handler and have db created call commands for other elements (instances/monitors)
    # Need to put here for now as the number of events coming during migration ended up in a :shutdown scenario
    # because of the tables not existing yet and want to get to testing
    Backend.Repo.create_tenant(c.id)

    account
    |> Multi.new()
    |> Multi.execute(&create_account(&1, c.id, c.name))
    |> Multi.execute(&select_monitors(&1, c.selected_monitors))
    |> Multi.execute(&select_instances_bulk(&1, c.selected_instances))
    |> Multi.execute(&add_user_to_account(&1, c.creating_user_id))
  end

  def execute(_account, %Commands.Create{}) do
    # Ignore duplicates
    nil
  end

  # Everything below cannot continue if account id is nil.

  def execute(%__MODULE__{id: nil}, c) do
    raise "Tried to execute command on an unknown account.\ncommand: #{inspect(c)}"
  end

  def execute(account, c = %Commands.UpdateName{}) do
    existing_name = account.name
    case c.name do
      nil ->
        nil
      ^existing_name ->
        nil
      _ ->
        c
        |> make_event(Events.NameUpdated)
        |> Domain.CryptUtils.encrypt("account")
    end
  end

  def execute(_account, c = %Commands.UpdateFreeTrial{}) do
    make_event(c, Events.FreeTrialUpdated)
  end

  def execute(account, c = %Commands.ChooseMonitors{}) do
    account
    |> Multi.new()
    |> Multi.execute(&select_monitors(&1, c.add_monitors))
    |> Multi.execute(&deselect_monitors(&1, c.remove_monitors))
  end

  def execute(account, c = %Commands.SetMonitors{}) do
    to_add =
      c.monitors
      |> Enum.reject(fn mon -> Enum.any?(account.monitors, &(&1.logical_name == mon.logical_name)) end)
      |> Enum.map(fn mon_to_add ->
        mon_to_add
          |> Map.put(:default_degraded_threshold, 5.0)
          |> Map.put(:instances, [])
          |> Map.put(:check_configs, [])
      end)

    to_remove =
      account.monitors
      |> Enum.reject(fn mon -> Enum.any?(c.monitors, &(&1.logical_name == mon.logical_name)) end)
      |> Enum.map(&(&1.logical_name))

    account
    |> Multi.new()
    |> Multi.execute(&select_monitors(&1, to_add))
    |> Multi.execute(&deselect_monitors(&1, to_remove))
  end

  def execute(account, c = %Commands.AddMonitor{}) do
    select_monitors(account, [
      %{
        logical_name: c.logical_name,
        name: c.name,
        default_degraded_threshold: c.default_degraded_threshold,
        instances: c.instances,
        check_configs: c.check_configs
      }
    ])
  end

  def execute(account, c = %Commands.AddUser{}) do
    unless Enum.member?(account.user_ids, c.user_id) do
      make_event(c, Events.UserAdded)
    end
  end

  def execute(account, c = %Commands.RemoveUser{}) do
    if Enum.member?(account.user_ids, c.user_id) do
      %Events.UserRemoved{id: account.id, user_id: c.user_id}
    end
  end

  def execute(_account, c = %Commands.AttachSlackWorkspace{}) do
    make_event(c, Events.SlackWorkspaceAttached)
  end

  def execute(account, c = %Commands.RemoveSlackWorkspace{}) do
    account
    |> Multi.new()
    |> Multi.execute(fn account ->
      account.subscriptions
      |> Enum.filter(&(&1.slack_workspace_id == c.team_id))
      |> Enum.map(fn subscription ->
        %Events.SubscriptionDeleted{
          id: c.id,
          subscription_id: subscription.id
        }
      end)
    end)
    |> Multi.execute(fn _account -> make_event(c, Events.SlackWorkspaceRemoved) end)
  end

  def execute(_account, c = %Commands.AttachMicrosoftTenant{}) do
    make_event(c, Events.MicrosoftTenantAttached)
  end

  def execute(_account, c = %Commands.UpdateMicrosoftTenant{}) do
    make_event(c, Events.MicrosoftTenantUpdated)
  end

  def execute(_account, c = %Commands.MakeInternal{}) do
    make_event(c, Events.MadeInternal)
  end

  def execute(_account, c = %Commands.MakeExternal{}) do
    make_event(c, Events.MadeExternal)
  end

  def execute(_account, c = %Commands.AddAPIToken{}) do
    make_event(c, Events.APITokenAdded)
  end

  def execute(_account, c = %Commands.RemoveAPIToken{}) do
    make_event(c, Events.APITokenRemoved)
  end

  def execute(_account, c = %Commands.RotateAPIToken{}) do
    [
      %Events.APITokenRemoved{
        id: c.id,
        api_token: c.existing_api_token
      },
      %Events.APITokenAdded{
        id: c.id,
        api_token: c.new_api_token
      }
    ]
  end

  def execute(account, _ = %Commands.Print{}) do
    IO.inspect(account)
    nil
  end

  def execute(account, c = %Commands.AddSlackSlashCommand{}) do
    %Events.SlackSlashCommandAdded{id: account.id, command_id: Domain.Id.new(), data: c.data}
  end

  def execute(account, c = %Commands.AddMicrosoftTeamsCommand{}) do
    %Events.MicrosoftTeamsCommandAdded{id: account.id, command_id: Domain.Id.new(), data: c.data}
  end

  def execute(account, c = %Commands.AddSubscriptions{}) do
    # We filter out known IDs so this command is idempotent. This makes migration simpler.
    existing_subscription_ids =
      account.subscriptions
      |> Enum.map(&(&1.id))

    c.subscriptions
    |> Enum.filter(fn subscription -> subscription.subscription_id not in existing_subscription_ids end)
    |> Enum.map(fn subscription ->
      %Events.SubscriptionAdded{
        id: c.id,
        subscription_id: subscription.subscription_id,
        monitor_id: subscription.monitor_id,
        delivery_method: subscription.delivery_method,
        identity: subscription.identity,
        regions: subscription.regions,
        display_name: subscription.display_name,
        extra_config: subscription.extra_config
      }
    end)
  end

  def execute(_account, c = %Commands.AddAlerts{}) do
    c.alerts
    |> Enum.map(fn alert ->
      make_event(alert, Events.AlertAdded)
      |> Map.put(:id, c.id)
    end)
  end

  def execute(account, c = %Commands.DispatchAlert{}) do
    # Only emit AlertDispatched if the account actually has subscriptions for this monitor
    if Enum.any?(account.subscriptions, &(&1.monitor_logical_name == c.alert.monitor_logical_name)) do
      make_event(c, Events.AlertDispatched)
    end
  end

  def execute(_account, c = %Commands.DropAlert{}) do
    make_event(c, Events.AlertDropped)
  end

  def execute(_account, c = %Commands.AddAlertDeliveries{}) do
    c.alert_deliveries
    |> Enum.map(fn ad ->
      %Events.AlertDeliveryAdded{
        id: c.id,
        alert_delivery_id: ad.alert_delivery_id,
        alert_id: ad.alert_id,
        delivery_method: ad.delivery_method,
        delivered_by_region: ad.delivered_by_region,
        started_at: ad.started_at,
        completed_at: ad.completed_at
      }
    end)
  end

  def execute(_account, c = %Commands.CompleteAlertDelivery{}) do
    make_event(c, Events.AlertDeliveryCompleted)
  end

  def execute(account, c = %Commands.DeleteSubscriptions{}) do
    # We only emit events for known IDs
    existing_subscription_ids =
      account.subscriptions
      |> Enum.map(&(&1.id))

    c.subscription_ids
    |> Enum.filter(fn subscription_id -> subscription_id in existing_subscription_ids end)
    |> Enum.map(fn subscription_id ->
      %Events.SubscriptionDeleted{
        id: c.id,
        subscription_id: subscription_id
      }
    end)
  end

  def execute(_account, c = %Commands.AddSubscriptionDelivery{}) do
    make_event(c, Events.SubscriptionDeliveryAdded)
    |> Map.put(:subscription_delivery_id, Domain.Id.new())
  end

  def execute(_account, c = %Commands.AddSubscriptionDeliveryV2{}) do
    make_event(c, Events.SubscriptionDeliveryAddedV2)
    |> Map.put(:subscription_delivery_id, Domain.Id.new())
  end

  def execute(account, c = %Commands.SetVisibleMonitors{}) do
    current = MapSet.new(account.visible_monitors)
    new = MapSet.new(c.monitor_logical_names)
    to_add = MapSet.difference(new, current)
    to_remove = MapSet.difference(current, new)
    [
      Enum.map(to_add, &(%Events.VisibleMonitorAdded{id: account.id, monitor_logical_name: &1})),
      Enum.map(to_remove, &(%Events.VisibleMonitorRemoved{id: account.id, monitor_logical_name: &1})),
    ]
    |> List.flatten()
  end

  def execute(%__MODULE__{ visible_monitors: [] }, c = %Commands.AddVisibleMonitor{}) do
    Logger.info("#{c.id}: visible_monitor added when account already has all monitors visible, ignoring. #{inspect c}")
    nil
  end
  def execute(account, c = %Commands.AddVisibleMonitor{}) do
    case Enum.find(account.visible_monitors, fn visibile_monitor -> visibile_monitor == c.monitor_logical_name end) do
      nil ->
        make_event(c, Events.VisibleMonitorAdded)
      _ ->
        Logger.info("#{c.id}: duplicate visible_monitor added, ignoring. New: #{inspect c}")
        nil
    end
  end

  def execute(%__MODULE__{ visible_monitors: [] }, c = %Commands.RemoveVisibleMonitor{}) do
    Logger.info("#{c.id}: requested a visible_monitor removal when an account has all monitors visible. Please use SetVisibleMonitors to set the full list of visible monitors. ignoring. #{inspect c}")
    nil
  end
  def execute(account, c = %Commands.RemoveVisibleMonitor{}) do
    case Enum.find(account.visible_monitors, fn visibile_monitor -> visibile_monitor == c.monitor_logical_name end) do
      nil ->
        Logger.info("#{c.id}: Attempted to remove non existent visible monitor, ignoring. Removed: #{inspect c}")
        nil
      _ ->
        make_event(c, Events.VisibleMonitorRemoved)
    end
  end

  def execute(account, c = %Commands.SetInstances{}) do
    current = MapSet.new(account.instances)
    new = MapSet.new(c.instances)
    to_add = MapSet.difference(new, current)
    to_remove = MapSet.difference(current, new)
    [
      Enum.map(to_add, &(%Events.InstanceAdded{id: account.id, instance_name: &1})),
      Enum.map(to_remove, &(%Events.InstanceRemoved{id: account.id, instance_name: &1})),
    ]
    |> List.flatten()
  end

  def execute(account, c = %Commands.AddInstance{}) do
    case Enum.find(account.instances, fn instance -> instance == c.instance_name end) do
      nil ->
        make_event(c, Events.InstanceAdded)
      _ ->
        Logger.info("#{c.id}: duplicate instance added, ignoring. New: #{inspect c}")
        nil
    end
  end

  def execute(account, c = %Commands.RemoveInstance{}) do
    case Enum.find(account.instances, fn instance -> instance == c.instance_name end) do
      nil ->
        Logger.info("#{c.id}: Attempted to remove non existent instance, ignoring. Removed: #{inspect c}")
        nil
      _ ->
        make_event(c, Events.InstanceRemoved)
    end
  end

  def execute(_account, c = %Commands.SetStripeCustomerId{}) do
    make_event(c, Events.StripeCustomerIdSet)
  end

  def execute(_account, c = %Commands.CreateMembership{}) do
    %Domain.Account.Events.MembershipCreated{
      id: c.id,
      membership_id: Domain.Id.new(),
      tier: c.tier,
      billing_period: c.billing_period,
      start_date: NaiveDateTime.utc_now()
    }
  end

  def execute(_account, c = %Commands.StartMembershipIntent{}) do
    make_event(c, Events.MembershipIntentStarted)
  end

  def execute(%{membership_intent: nil}, %Commands.CompleteMembershipIntent{}), do: nil
  def execute(account, c = %Commands.CompleteMembershipIntent{}) do
    if account.membership_intent.callback_reference == c.callback_reference do
      %Domain.Account.Events.MembershipCreated{
        id: c.id,
        membership_id: Domain.Id.new(),
        tier: account.membership_intent.tier,
        billing_period: account.membership_intent.billing_period,
        start_date: NaiveDateTime.utc_now()
      }
    else
      nil
    end
  end

  # Event handling

  def apply(account, e = %Events.Created{}) do
    %__MODULE__{
      account
      | id: e.id,
        name: e.name,
        monitors: [],
        instances: [],
        slack_workspaces: [],
        is_internal: false,
        api_tokens: []
    }
  end

  def apply(account, e = %Events.NameUpdated{}) do
    %__MODULE__{account | name: e.name}
  end

  def apply(account, _e = %Events.FreeTrialUpdated{}) do
    account
  end

  def apply(account, e = %Events.InstanceAdded{}) do
    %__MODULE__{account |
                instances: Enum.uniq([e.instance_name | account.instances])}
  end

  def apply(account, e = %Events.InstanceRemoved{}) do
    %__MODULE__{account |
                instances: account.instances -- [e.instance_name]}
  end

  def apply(account, e = %Events.VisibleMonitorAdded{}) do
    %__MODULE__{account |
                visible_monitors: Enum.uniq([e.monitor_logical_name | account.visible_monitors])}
  end

  def apply(account, e = %Events.VisibleMonitorRemoved{}) do
    %__MODULE__{account |
                visible_monitors: account.visible_monitors -- [e.monitor_logical_name]}
  end

  def apply(account, e = %Events.InstancesAdded{}) do
    %__MODULE__{account |
                instances: Enum.uniq(e.instances ++ account.instances)}
  end

  def apply(account, %Events.SlackWorkspaceAttached{}) do
    # TODO actually store this once we have a use for it.
    account
  end

  def apply(account, %Events.SlackWorkspaceRemoved{}) do
    # Nothing to do on the aggregate currently
    account
  end

  def apply(account, %Events.TeamsWorkspaceAttached{}) do
    # Obsolete but we will see replays of it so leave it in.
    account
  end

  def apply(account, %Events.MicrosoftTenantAttached{}) do
    # TODO actually store this once we have a use for it.
    account
  end

  def apply(account, %Events.MicrosoftTenantUpdated{}) do
    account
  end

  def apply(account, e = %Events.UserAdded{}) do
    %__MODULE__{account |
                user_ids: Enum.uniq([e.user_id | account.user_ids])}
  end

  def apply(account, e = %Events.UserRemoved{}) do
    %__MODULE__{account |
                user_ids: account.user_ids -- [e.user_id]}
  end

  def apply(account, e = %Events.MonitorAdded{}) do
    %__MODULE__{
      account
      | monitors: [
          %Monitor{
            logical_name: e.logical_name
          }
          | account.monitors
        ]
    }
  end

  def apply(account, e = %Events.MonitorRemoved{}) do
    %__MODULE__{
      account
      | monitors: Enum.reject(account.monitors, &(&1.logical_name == e.logical_name))
    }
  end

  def apply(account, %Events.SnapshotStored{}) do
    account
  end

  def apply(account, %Events.MadeInternal{}) do
    %__MODULE__{account | is_internal: true}
  end

  def apply(account, %Events.MadeExternal{}) do
    %__MODULE__{account | is_internal: false}
  end

  def apply(account, e = %Events.APITokenAdded{}) do
    %__MODULE__{account | api_tokens: [e.api_token | account.api_tokens]}
  end

  def apply(account, e = %Events.APITokenRemoved{}) do
    %__MODULE__{account | api_tokens: account.api_tokens -- [e.api_token]}
  end

  # In case logic is needed here, see `id_of` for how to deal with old events
  def apply(account, _ = %Events.SlackSlashCommandAdded{}) do
    account
  end

  # In case logic is needed here, see `id_of` for how to deal with old events
  def apply(account, _ = %Events.MicrosoftTeamsCommandAdded{}) do
    account
  end

  def apply(account, e = %Events.SubscriptionAdded{}) do
    new_subscription = %Subscription {
      id: e.subscription_id,
      delivery_method: e.delivery_method,
      monitor_logical_name: e.monitor_id,
      slack_workspace_id: get_slack_workpace_from_subscription_added(e)
    }
    %__MODULE__{account | subscriptions: [new_subscription | account.subscriptions]}
  end

  def apply(account, e = %Events.SubscriptionDeleted{}) do
    %__MODULE__{account | subscriptions: Enum.reject(account.subscriptions, &(&1.id == e.subscription_id))}
  end

  def apply(account, _e = %Events.AlertAdded{}) do
    account
    #__MODULE__{account | alert_ids: [e.alert_id | account.alert_ids]}
  end

  def apply(account, _e = %Events.AlertDispatched{}) do
    account
  end

  def apply(account, _e = %Events.AlertDropped{}) do
    account
  end

  def apply(account, _e = %Events.AlertDeliveryAdded{}) do
    account
    #%__MODULE__{account | alert_delivery_ids: [e.alert_delivery_id | account.alert_delivery_ids]}
  end

  def apply(account, %Events.AlertDeliveryCompleted{}) do
    account
  end

  def apply(account, %Events.SubscriptionDeliveryAdded{}) do
    account
  end

  def apply(account, %Events.SubscriptionDeliveryAddedV2{}) do
    account
  end

  def apply(account, %Events.StripeCustomerIdSet{customer_id: customer_id}) do
    %__MODULE__{account | stripe_customer_id: customer_id}
  end

  def apply(account, %Events.MembershipCreated{membership_id: id}) do
    %__MODULE__{account | membership_id: id, membership_intent: nil}
  end

  def apply(account, e=%Events.MembershipIntentStarted{}) do
    %__MODULE__{account | membership_intent: %{
                            tier: e.tier,
                            billing_period: e.billing_period,
                            callback_reference: e.callback_reference}}
  end

  # Account creation. Note that the execution order of Multi is: execute
  # the command function, apply any events, execute the next command function
  # so that the passed in "account" is always up-to-date.

  defp create_account(_account, id, name) do
    free_trial_end_time = NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> Timex.shift(days: 30)

    %Events.Created{
      id: id,
      name: name,
      free_trial_end_time: free_trial_end_time
    } |> Domain.CryptUtils.encrypt("account")
  end

  defp select_monitors(account, monitors) do
    monitors
    |> Enum.reject(&Enum.any?(account.monitors, fn m -> m.logical_name == &1.logical_name end))
    |> Enum.map(
      &%Events.MonitorAdded{
        id: account.id,
        logical_name: &1.logical_name,
        name: &1.name,
        default_degraded_threshold: &1.default_degraded_threshold,
        instances: &1.instances,
        check_configs: &1.check_configs
      }
    )
  end

  defp deselect_monitors(account, monitors) do
    monitor_removed_events =
      monitors
      |> Enum.filter(&Enum.any?(account.monitors, fn m -> m.logical_name == &1 end))
      |> Enum.map(&%Events.MonitorRemoved{id: account.id, logical_name: &1})

    subscription_deleted_events =
      account.subscriptions
      |> Enum.filter(&Enum.any?(monitors, fn mon -> mon == &1.monitor_logical_name end))
      |> Enum.map(fn subscription ->
        %Events.SubscriptionDeleted{
          id: account.id,
          subscription_id: subscription.id
        }
      end)

    monitor_removed_events ++ subscription_deleted_events
  end

  defp select_instances_bulk(account, instances) do
    %Events.InstancesAdded{id: account.id, instances: instances}
  end

  defp add_user_to_account(account, user_id) do
    %Events.UserAdded{id: account.id, user_id: user_id}
  end

  defp get_slack_workpace_from_subscription_added(%Domain.Account.Events.SubscriptionAdded{ delivery_method: "slack", extra_config: extra_config}) do
    # All of the existing code will send in "WorkspaceId" as a string key for slack subscriptions.
    # When re-applying these events it will be turned into an atom so handle both.
    if Map.has_key?(extra_config, "WorkspaceId") do
      extra_config
      |> Map.get("WorkspaceId")
    else
      extra_config
      |> Map.get(:WorkspaceId)
    end
  end
  defp get_slack_workpace_from_subscription_added(_), do: nil


  @doc """
  Similar to some of the monitor events, these events were not settting their id to the aggregate root.
  These helpers are required when trying to get the unique id of each object such as in projections or event
  business logic

  There is no event handling here currently but a note weas added to look at id_of if required in the future
  """
  def id_of(e = %Events.SlackSlashCommandAdded{}), do: Domain.Helpers.id_of(e, :command_id)
  def id_of(e = %Events.MicrosoftTeamsCommandAdded{}), do: Domain.Helpers.id_of(e, :command_id)

  def free_trial_days_left(end_time) when end_time != nil do
    diff = Timex.diff(end_time, NaiveDateTime.utc_now(), :days)

    if diff > 0 do
      diff + 1
    else
      0
    end
  end
  def free_trial_days_left(_), do: 0
end
