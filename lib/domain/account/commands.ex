defmodule Domain.Account.Commands do
  use TypedStruct

  typedstruct module: Create, enforce: true do
    use Domo
    field :id, String.t
    field :creating_user_id, String.t
    field :name, String.t, enforce: false
    field :selected_monitors, [map()]
    field :selected_instances, [String.t]
  end

  typedstruct module: UpdateName do
    use Domo
    field :id, String.t, enforce: true
    field :name, String.t
  end

  typedstruct module: UpdateFreeTrial, enforce: true do
    use Domo
    field :id, String.t()
    field :free_trial_end_time, NaiveDateTime.t()
  end

  typedstruct module: AddUser, enforce: true do
    use Domo
    field :id, String.t
    field :user_id, String.t
  end

  typedstruct module: AttachSlackWorkspace, enforce: true do
    use Domo
    field :id, String.t
    field :integration_id, String.t
    field :team_id, String.t
    field :team_name, String.t
    field :scope, [String.t]
    field :bot_user_id, String.t
    field :access_token, String.t
    field :message, String.t, enforce: false
  end

  typedstruct module: RemoveSlackWorkspace, enforce: true do
    use Domo
    field :id, String.t
    field :team_id, String.t
  end

  typedstruct module: AttachMicrosoftTenant, enforce: true do
    use Domo
    field :id, String.t
    field :tenant_id, String.t
    field :name, String.t, enforce: false
    field :team_id, String.t, enforce: false
    field :team_name, String.t, enforce: false
    field :service_url, String.t, enforce: false
  end

  typedstruct module: UpdateMicrosoftTenant, enforce: true do
    use Domo
    field :id, String.t
    field :tenant_id, String.t
    field :team_id, String.t
    field :team_name, String.t
    field :service_url, String.t
  end

  typedstruct module: ChooseMonitors, enforce: true do
    use Domo
    field :id, String.t
    field :user_id, String.t
    field :add_monitors, [map()]
    field :remove_monitors, [String.t]
  end

  typedstruct module: MonitorSpec, enforce: true do
    use Domo
    field :logical_name, String.t
    field :name, String.t
  end

  typedstruct module: SetMonitors, enforce: true do
    use Domo
    field :id, String.t
    field :monitors, [MonitorSpec.t]
  end

  typedstruct module: AddMonitor, enforce: true do
    use Domo
    field :id, String.t
    field :logical_name, String.t
    field :name, String.t
    field :default_degraded_threshold, float
    field :instances, [String.t]
    field :check_configs, [map()]
  end

  typedstruct module: MakeInternal, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: MakeExternal, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: AddAPIToken, enforce: true do
    use Domo
    field :id, String.t
    field :api_token, String.t
  end

  typedstruct module: RemoveAPIToken, enforce: true do
    use Domo
    field :id, String.t
    field :api_token, String.t
  end

  typedstruct module: RotateAPIToken, enforce: true do
    use Domo
    field :id, String.t
    field :existing_api_token, String.t
    field :new_api_token, String.t
  end

  typedstruct module: Print, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: AddSlackSlashCommand, enforce: true do
    use Domo
    field :id, String.t
    field :data, map()
  end

  typedstruct module: AddMicrosoftTeamsCommand, enforce: true do
    use Domo
    field :id, String.t
    field :data, map()
  end

  typedstruct module: Subscription, enforce: true do
    use Domo
    field :subscription_id, String.t
    field :monitor_id, String.t
    field :delivery_method, String.t
    field :identity, String.t
    field :regions, [String.t] | nil
    field :extra_config, map()
    field :display_name, String.t
  end
  typedstruct module: AddSubscriptions, enforce: true do
    use Domo
    field :id, String.t
    field :subscriptions, [Subscription.t]
  end

  typedstruct module: DeleteSubscriptions, enforce: true do
    use Domo
    field :id, String.t
    field :subscription_ids, [String.t]
  end

  typedstruct module: Alert, enforce: true do
    use Domo
    @derive Jason.Encoder # We're using this in other places than commands.
    field :alert_id, String.t
    field :correlation_id, String.t
    field :monitor_logical_name, String.t
    field :state, String.t | Backend.Projections.Dbpa.Snapshot.state()
    field :is_instance_specific, boolean
    field :subscription_id, String.t, enforce: false
    field :formatted_messages, map()
    field :affected_regions, [String.t]
    field :affected_checks, [map()]
    field :generated_at, NaiveDateTime.t
    field :monitor_name, String.t, enforce: false
  end

  typedstruct module: AddAlerts, enforce: true do
    use Domo
    field :id, String.t
    field :alerts, [Alert.t]
  end

  # DispatchAlert has its own Alert.t() struct here so that sending can happen
  # immediately upon receipt of AlertDispatched instead of having to wait
  # and retry the reading of the alert from the projection db because of EC
  # Need enough info here to actually send it
  typedstruct module: DispatchAlert, enforce: true do
    use Domo
    field :id, String.t
    field :alert, Alert.t()
  end

  typedstruct module: DropAlert, enforce: true do
    use Domo
    field :id, String.t
    field :reason, String.t | atom()
    field :alert_id, String.t
  end

  typedstruct module: AlertDelivery, enforce: true do
    use Domo
    field :id, String.t
    field :alert_delivery_id, String.t
    field :alert_id, String.t
    field :delivery_method, String.t
    field :delivered_by_region, String.t
    field :started_at, NaiveDateTime.t | String.t
    field :completed_at, NaiveDateTime.t | String.t, enforce: false
  end
  typedstruct module: AddAlertDeliveries, enforce: true do
    use Domo
    field :id, String.t
    field :alert_deliveries, [AlertDelivery.t]
  end

  typedstruct module: CompleteAlertDelivery, enforce: true do
    use Domo
    field :id, String.t
    field :alert_delivery_id, String.t
    field :completed_at, NaiveDateTime.t, enforce: false
  end

  typedstruct module: RemoveUser, enforce: true do
    use Domo
    field :id, String.t
    field :user_id, String.t
  end

  typedstruct module: AddSubscriptionDelivery, enforce: true do
    use Domo
    field :id, String.t
    field :monitor_logical_name, String.t
    field :alert_id, String.t
    field :subscription_id, String.t
    field :delivery_method, String.t
    field :display_name, String.t
    field :result, String.t
    field :status_code, integer
  end

  typedstruct module: AddSubscriptionDeliveryV2, enforce: true do
    use Domo
    field :id, String.t
    field :alert_id, String.t
    field :subscription_id, String.t
    field :status_code, integer
  end

  typedstruct module: SetVisibleMonitors, enforce: true do
    use Domo
    field :id, String.t()
    field :monitor_logical_names, [String.t()]
  end

  typedstruct module: AddVisibleMonitor, enforce: true do
    use Domo
    field :id, String.t()
    field :monitor_logical_name, String.t()
  end

  typedstruct module: RemoveVisibleMonitor, enforce: true do
    use Domo
    field :id, String.t()
    field :monitor_logical_name, String.t()
  end

  typedstruct module: SetInstances, enforce: true do
    use Domo
    field :id, String.t()
    field :instances, [String.t()]
  end

  typedstruct module: AddInstance, enforce: true do
    use Domo
    field :id, String.t()
    field :instance_name, String.t()
  end

  typedstruct module: RemoveInstance, enforce: true do
    use Domo
    field :id, String.t()
    field :instance_name, String.t()
  end

  typedstruct module: SetStripeCustomerId, enforce: true do
    use Domo
    field :id, String.t()
    field :customer_id, String.t()
  end

  typedstruct module: StartMembershipIntent, enforce: true do
    use Domo
    field :id, String.t()
    field :tier, String.t()
    field :billing_period, String.t()
    field :callback_reference, String.t()
  end

  typedstruct module: CompleteMembershipIntent, enforce: true do
    use Domo
    field :id, String.t()
    field :callback_reference, String.t()
  end

  typedstruct module: CreateMembership, enforce: true do
    use Domo
    field :id, String.t()
    field :tier, String.t()
    field :billing_period, String.t()
  end
end
