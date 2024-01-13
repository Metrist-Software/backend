defmodule Domain.Monitor.Events do
  use TypedStruct

  typedstruct module: Created, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :name, String.t(), enforce: false
  end

  typedstruct module: Updated, enforce: true do
    @moduledoc "Deprecated: see `Domain.Monitor.Events.Created`"
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :name, String.t()
  end

  typedstruct module: LastReportTimeUpdated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :last_report, NaiveDateTime.t()
  end

  typedstruct module: CheckAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :logical_name, String.t()
    field :name, String.t()
    field :is_private, boolean
  end

  typedstruct module: CheckNameUpdated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :logical_name, String.t()
    field :name, String.t()
  end

  typedstruct module: EventsInvalidated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :logical_name, String.t()
    field :check_logical_name, String.t()
    field :start_time, NaiveDateTime.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: ErrorsInvalidated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :logical_name, String.t()
    field :check_logical_name, String.t()
    field :start_time, NaiveDateTime.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: InstanceAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :last_report, NaiveDateTime.t()
    field :check_last_reports, map()
  end

  typedstruct module: InstanceRemoved, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
  end

  typedstruct module: InstanceUpdated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :last_report, NaiveDateTime.t()
  end

  typedstruct module: InstanceCheckUpdated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :check_logical_name, String.t()
    field :last_report, NaiveDateTime.t()
  end

  typedstruct module: ConfigAdded, enforce: true do
    use Domain.CryptUtils, fields: [:extra_config]
    plugin Backend.JsonUtils
    field :id, String.t()
    field :config_id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :interval_secs, integer
    field :extra_config, %{}
    field :run_groups, [String.t()]
    field :run_spec, Domain.Monitor.Commands.RunSpec.t()
    field :steps, [Domain.Monitor.Commands.Step.t()]
  end

  typedstruct module: AnalyzerConfigAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :default_degraded_threshold, float
    field :instances, [String.t()]
    # TODO: Transform this into an actual list of defined Structs (will likely require a v2 event as the casing is in C# syntax for past events)
    field :check_configs, [map()]
    field :default_degraded_down_count, integer, enforce: false
    field :default_degraded_up_count, integer, enforce: false
    field :default_degraded_timeout, integer, enforce: false
    field :default_error_timeout, integer, enforce: false
    field :default_error_down_count, integer, enforce: false
    field :default_error_up_count, integer, enforce: false
    field :monitor_name, String.t(), enforce: false
  end

  typedstruct module: AnalyzerConfigUpdated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :default_degraded_threshold, float
    field :instances, [String.t()]
    # TODO: Transform this into an actual list of defined Structs (will likely require a v2 event as the casing is in C# syntax for past events)
    field :check_configs, [map()]
    field :default_degraded_down_count, integer, enforce: false
    field :default_degraded_up_count, integer, enforce: false
    field :default_degraded_timeout, integer, enforce: false
    field :default_error_timeout, integer, enforce: false
    field :default_error_down_count, integer, enforce: false
    field :default_error_up_count, integer, enforce: false
  end

  typedstruct module: AnalyzerConfigRemoved, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
  end

  typedstruct module: ErrorAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :error_id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :check_logical_name, String.t()
    field :message, String.t()
    field :time, NaiveDateTime.t()
    field :metadata, Domain.Monitor.Commands.metadata(), default: %{}
    field :blocked_steps, [String.t()], default: []
  end

  typedstruct module: EventAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :event_id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :check_logical_name, String.t()
    field :message, String.t()
    field :state, String.t()
    field :start_time, NaiveDateTime.t()
    field :end_time, NaiveDateTime.t()
    field :correlation_id, String.t()
  end

  typedstruct module: EventEnded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :monitor_event_id, String.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: EventsCleared, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: TelemetryAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :check_logical_name, String.t()
    field :instance_name, String.t()
    field :is_private, boolean
    field :value, float
    field :created_at, NaiveDateTime.t()
    field :metadata, Domain.Monitor.Commands.metadata(), default: %{}
  end

  typedstruct module: TagAdded, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :tag, String.t()
  end

  typedstruct module: TagChanged, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :from_tag, String.t()
    field :to_tag, String.t()
  end

  typedstruct module: TagRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :tag, String.t()
  end

  typedstruct module: Reset, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
  end

  typedstruct module: ExtraConfigSet, enforce: true do
    plugin Backend.JsonUtils
    use Domain.CryptUtils, fields: [:value]
    field :id, String.t()
    field :account_id, String.t()
    field :config_id, String.t()
    field :key, String.t()
    field :value, String.t()
  end

  typedstruct module: RunGroupsSet, enforce: true do
    @derive Jason.Encoder
    # FIXME in the database
    field :id, String.t()
    field :config_id, String.t()
    field :account_id, String.t()
    field :check_logical_name, String.t(), enforce: false
    field :run_groups, [String.t()]
  end

  typedstruct module: RunSpecSet, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :config_id, String.t()
    field :account_id, String.t()
    field :run_spec, Domain.Monitor.Commands.RunSpec.t()
  end

  typedstruct module: StepsSet, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :config_id, String.t()
    field :account_id, String.t()
    field :steps, [Domain.Monitor.Commands.Step.t()]
    field :monitor_logical_name, String.t(), enforce: false
  end

  typedstruct module: IntervalSecsSet, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :config_id, String.t()
    field :account_id, String.t()
    field :interval_secs, integer
  end

  typedstruct module: ConfigRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_config_id, String.t()
  end

  typedstruct module: CheckRemoved, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :check_logical_name, String.t()
  end

  typedstruct module: NameChanged, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :name, String.t()
  end

  typedstruct module: TwitterHashtagsSet, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :hashtags, [String.t()]
  end

  typedstruct module: TwitterCountAdded, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :hashtag, String.t()
    field :bucket_end_time, NaiveDateTime.t()
    field :bucket_duration, pos_integer()
    field :count, non_neg_integer()
  end

  typedstruct module: MonitorToggledEvent, enforce: true do
    @moduledoc deprecated: "Obsolete. This was used to toggle the monitor state to :maintenance which we dont do anymore"
    plugin Backend.JsonUtils
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :state, String.t()
  end
end
