defmodule Domain.Account.Events do
  use TypedStruct

  typedstruct module: Created, enforce: true do
    use Domain.CryptUtils, fields: [:name]
    @derive Jason.Encoder
    field :id, String.t()
    field :name, String.t(), enforce: false
    field :free_trial_end_time, NaiveDateTime.t(), enforce: false
  end

  typedstruct module: NameUpdated, enforce: true do
    use Domain.CryptUtils, fields: [:name]
    @derive Jason.Encoder
    field :id, String.t()
    field :name, String.t(), enforce: false
  end

  typedstruct module: FreeTrialUpdated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :free_trial_end_time, NaiveDateTime.t()
  end

  typedstruct module: MonitorAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :logical_name, String.t
    field :name, String.t
    field :default_degraded_threshold, float
    field :instances, [String.t]
    field :check_configs, [map()]
  end

  typedstruct module: MonitorRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t, enforce: true
    field :logical_name, String.t, enforce: true
  end

  typedstruct module: InstancesAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t(), enforce: true
    field :instances, [String.t()], enforce: true
  end

  typedstruct module: UserAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t(), enforce: true
    field :user_id, String.t(), enforce: true
  end

  typedstruct module: SlackWorkspaceAttached, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :integration_id, String.t
    field :team_id, String.t
    field :team_name, String.t
    field :scope, [String.t]
    field :bot_user_id, String.t
    field :access_token, String.t
    field :message, String.t, enforce: false
  end

  typedstruct module: SlackWorkspaceRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :team_id, String.t
  end

  typedstruct module: TeamsWorkspaceAttached, enforce: true do
    @moduledoc deprecated: "Obsolete, superceded by MicrosoftTenantAttached"
    @derive Jason.Encoder
    field :id, String.t
    field :tenant_uuid, String.t
  end

  typedstruct module: MicrosoftTenantAttached, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :tenant_id, String.t
    field :name, String.t, enforce: false
    field :team_id, String.t, enforce: false
    field :team_name, String.t, enforce: false
    field :service_url, String.t, enforce: false
  end

  typedstruct module: MicrosoftTenantUpdated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :tenant_id, String.t
    field :team_id, String.t
    field :team_name, String.t
    field :service_url, String.t
  end

  typedstruct module: SnapshotStored, enforce: true do
    @moduledoc "Deprecated: snapshots no longer processed through Commanded. See `Backend.Projections.Dbpa.Snapshot`"
    @derive Jason.Encoder
    field :id, String.t
    field :name, String.t
    field :data, map()
  end

  typedstruct module: MadeInternal, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
  end

  typedstruct module: MadeExternal, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
  end

  typedstruct module: APITokenAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :api_token, String.t
  end

  typedstruct module: APITokenRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :api_token, String.t
  end

  typedstruct module: SlackSlashCommandAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :data, map()
    field :command_id, String.t, enforce: false
  end

  typedstruct module: MicrosoftTeamsCommandAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :data, map()
    field :command_id, String.t, enforce: false
  end

  typedstruct module: SubscriptionAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :subscription_id, String.t
    field :display_name, String.t
    field :monitor_id, String.t
    field :delivery_method, String.t
    field :identity, String.t
    field :regions, [String.t]
    field :extra_config, map()
  end

  typedstruct module: SubscriptionDeleted, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :subscription_id, String.t
  end

  typedstruct module: AlertAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :alert_id, String.t
    field :correlation_id, String.t
    field :monitor_logical_name, String.t
    field :state, String.t
    field :is_instance_specific, boolean
    field :subscription_id, String.t
    field :formatted_messages, map()
    field :affected_regions, [String.t]
    field :affected_checks, [map()]
    field :generated_at, NaiveDateTime.t()
    field :monitor_name, String.t, enforce: false
  end

  # AlertDispatched has its own Alert.t() struct here so that sending can happen
  # immediately upon receipt of AlertDispatched instead of having to wait
  # and retry the reading of the alert from the projection db because of EC
  # Need enough info here to actually send it
  typedstruct module: AlertDispatched, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :alert, Domain.Account.Commands.Alert.t()
  end

  typedstruct module: AlertDropped, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :alert_id, String.t
    field :reason, String.t
  end

  typedstruct module: AlertDeliveryAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :alert_delivery_id, String.t
    field :alert_id, String.t
    field :delivery_method, String.t
    field :delivered_by_region, String.t
    field :started_at, NaiveDateTime.t()
    field :completed_at, NaiveDateTime.t()
  end

  typedstruct module: AlertDeliveryCompleted, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :alert_delivery_id, String.t
    field :completed_at, NaiveDateTime.t()
  end

  typedstruct module: UserRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t(), enforce: true
    field :user_id, String.t(), enforce: true
  end

  typedstruct module: SubscriptionDeliveryAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :subscription_delivery_id, String.t
    field :monitor_logical_name, String.t
    field :alert_id, String.t
    field :subscription_id, String.t
    field :delivery_method, String.t
    field :display_name, String.t
    field :result, String.t
    field :status_code, integer
  end

  typedstruct module: SubscriptionDeliveryAddedV2, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :subscription_delivery_id, String.t
    field :alert_id, String.t
    field :subscription_id, String.t
    field :status_code, integer
  end

  typedstruct module: VisibleMonitorAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :monitor_logical_name, String.t()
  end

  typedstruct module: VisibleMonitorRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :monitor_logical_name, String.t()
  end

  typedstruct module: InstanceAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :instance_name, String.t()
  end

  typedstruct module: InstanceRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :instance_name, String.t()
  end

  typedstruct module: StripeCustomerIdSet, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :customer_id, String.t()
  end

  typedstruct module: MembershipCreated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :membership_id, String.t()
    field :tier, String.t()
    field :billing_period, String.t()
    field :start_date, NaiveDateTime.t()
  end

  typedstruct module: MembershipIntentStarted, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :tier, String.t()
    field :billing_period, String.t()
    field :callback_reference, String.t()
  end
end
