defmodule Domain.Monitor.Commands do
  use TypedStruct

  # We limit metrics metadata to be a flat map of simple values.
  @type metadata_value :: String.t() | number()
  @type metadata :: %{optional(String.t()) => metadata_value()}

  typedstruct module: Create, enforce: true do
    use Domo
    field :id, String.t
    field :account_id, String.t
    field :monitor_logical_name, String.t
    field :name, String.t, enforce: false
  end

  typedstruct module: UpdateLastReportTime do
    use Domo
    field :id, String.t, enforce: true
    field :last_report, NaiveDateTime.t, enforce: true
  end

  typedstruct module: AddCheck, enforce: true do
    use Domo
    field :id, String.t
    field :logical_name, String.t
    field :name, String.t
    field :is_private, boolean
  end

  typedstruct module: UpdateCheckName, enforce: true do
    use Domo
    field :id, String.t
    field :logical_name, String.t
    field :name, String.t
  end

  typedstruct module: InvalidateEvents, enforce: true do
    field :id, String.t
    field :logical_name, String.t
    field :start_time, NaiveDateTime.t
    field :end_time, NaiveDateTime.t
    field :check_logical_name, String.t
    field :account_id, String.t
  end

  typedstruct module: InvalidateErrors, enforce: true do
    field :id, String.t
    field :logical_name, String.t
    field :start_time, NaiveDateTime.t
    field :end_time, NaiveDateTime.t
    field :check_logical_name, String.t
    field :account_id, String.t
  end

  typedstruct module: AddInstance, enforce: true do
    use Domo
    field :id, String.t
    field :instance_name, String.t
    field :last_report, NaiveDateTime.t
    field :check_last_reports, map()
  end

  typedstruct module: UpdateInstance, enforce: true do
    use Domo
    field :id, String.t
    field :account_id, String.t, enforce: true
    field :monitor_logical_name, String.t, enforce: true
    field :instance_name, String.t
    field :last_report, NaiveDateTime.t
  end

  typedstruct module: RemoveInstance, enforce: true do
    use Domo
    field :id, String.t
    field :instance_name, String.t
  end

  typedstruct module: UpdateInstanceCheck, enforce: true do
    use Domo
    field :id, String.t
    field :account_id, String.t, enforce: true
    field :monitor_logical_name, String.t, enforce: true
    field :instance_name, String.t
    field :check_logical_name, String.t
    field :last_report, NaiveDateTime.t
  end

  typedstruct module: RunSpec do
    use Domo
    @derive Jason.Encoder # We're using this in other places than commands.
    field :run_type, atom, enforce: true
    field :name, String.t # name is optional for e.g. the "ping" run_type.
  end

  typedstruct module: Step, enforce: true do
    use Domo
    @derive Jason.Encoder # We're using this in other places than commands.
    field :check_logical_name, String.t
    field :timeout_secs, number()
  end

  typedstruct module: AddConfig do
    use Domo
    field :id, String.t, enforce: true
    field :config_id, String.t, enforce: true
    field :account_id, String.t
    field :monitor_logical_name, String.t, enforce: true
    field :interval_secs, integer
    field :extra_config, map()
    field :run_groups, [String.t]
    field :run_spec, RunSpec.t()
    field :steps, [Step.t()]
  end

  typedstruct module: SetRunSpec, enforce: true do
    use Domo
    field :id, String.t()
    field :config_id, String.t()
    field :run_spec, RunSpec.t()
  end

  typedstruct module: SetSteps, enforce: true do
    use Domo
    field :id, String.t()
    field :config_id, String.t()
    field :steps, [Step.t()]
  end

  typedstruct module: AddAnalyzerConfig, enforce: true do
    use Domo
    field :id, String.t
    field :default_degraded_threshold, number()
    field :instances, [String.t]
    field :check_configs, [map()]
    field :default_degraded_down_count, integer, enforce: false
    field :default_degraded_up_count, integer, enforce: false
    field :default_degraded_timeout, integer, enforce: false
    field :default_error_timeout, integer, enforce: false
    field :default_error_down_count, integer, enforce: false
    field :default_error_up_count, integer, enforce: false
  end

  typedstruct module: UpdateAnalyzerConfig, enforce: true do
    use Domo
    field :id, String.t
    field :default_degraded_threshold, number()
    field :instances, [String.t]
    field :check_configs, [map()]
    field :default_degraded_down_count, integer, enforce: false
    field :default_degraded_up_count, integer, enforce: false
    field :default_degraded_timeout, integer, enforce: false
    field :default_error_timeout, integer, enforce: false
    field :default_error_down_count, integer, enforce: false
    field :default_error_up_count, integer, enforce: false
  end

  typedstruct module: AddError, enforce: true do
    @moduledoc """
    As an exception we send account_id and monitor_logical_name along,
    which is redundant but this way we can create a new monitor on-the-fly
    when telemetry arrives for an unknown monitor. If you're sure that that
    code path isn't used, it is fine to leave them nil.
    """
    use Domo
    field :id, String.t()
    field :account_id, String.t(), enforce: false
    field :monitor_logical_name, String.t(), enforce: false
    field :error_id, String.t()
    field :instance_name, String.t()
    field :check_logical_name, String.t()
    field :message, String.t()
    field :report_time, NaiveDateTime.t()
    field :metadata, Domain.Monitor.Commands.metadata(), default: %{}
    field :blocked_steps, [String.t()], default: []
    field :is_private, boolean
  end

  typedstruct module: AddEvent, enforce: true do
    use Domo
    field :id, String.t
    field :event_id, String.t
    field :instance_name, String.t
    field :check_logical_name, String.t
    field :state, String.t
    field :message, String.t
    field :start_time, NaiveDateTime.t
    field :end_time, NaiveDateTime.t | nil
    field :correlation_id, String.t
  end

  typedstruct module: EndEvent, enforce: true do
    use Domo
    field :id, String.t()
    field :monitor_event_id, String.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: ClearEvents, enforce: true do
    use Domo
    field :id, String.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: Print, enforce: true do
    use Domo
    field :id, String.t
    field :account_id, String.t, enforce: true
    field :monitor_logical_name, String.t, enforce: true
  end

  typedstruct module: AddTelemetry, enforce: true do
    @moduledoc """
    As an exception we send account_id and monitor_logical_name along,
    which is redundant but this way we can create a new monitor on-the-fly
    when telemetry arrives for an unknown monitor. If you're sure that that
    code path isn't used, it is fine to leave them nil.
    """
    use Domo
    field :id, String.t
    field :account_id, String.t, enforce: false
    field :monitor_logical_name, String.t, enforce: false
    field :instance_name, String.t
    field :check_logical_name, String.t
    field :value, number()
    field :is_private, boolean
    field :report_time, NaiveDateTime.t
    field :metadata, Domain.Monitor.Commands.metadata(), default: %{}
  end

  typedstruct module: AddTag, enforce: true do
    use Domo
    field :id, String.t
    field :tag, String.t
  end

  typedstruct module: RemoveTag, enforce: true do
    use Domo
    field :id, String.t
    field :tag, String.t
  end

  typedstruct module: ChangeTag, enforce: true do
    @doc """
    Changes the tag _if the old one exists on the monitor_.
    """
    use Domo
    field :id, String.t()
    field :from_tag, String.t()
    field :to_tag, String.t()
  end

  typedstruct module: Reset, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: SetExtraConfig, enforce: true do
    use Domo
    field :id, String.t()
    field :config_id, String.t()
    field :key, String.t()
    field :value, String.t()
  end

  typedstruct module: SetRunGroups, enforce: true do
    use Domo
    field :id, String.t()
    field :config_id, String.t()
    field :run_groups, [String.t()]
  end

  typedstruct module: SetIntervalSecs, enforce: true do
    use Domo
    field :id, String.t()
    field :config_id, String.t()
    field :interval_secs, integer
  end

  typedstruct module: RemoveConfig, enforce: true do
    use Domo
    field :id, String.t
    field :config_id, String.t
  end

  typedstruct module: RemoveCheck, enforce: true do
    use Domo
    field :id, String.t
    field :check_logical_name, String.t
  end

  typedstruct module: ChangeName, enforce: true do
    use Domo
    field :id, String.t()
    field :name, String.t()
  end

  typedstruct module: SetTwitterHashtags, enforce: true do
    use Domo
    field :id, String.t()
    field :hashtags, [String.t()]
  end

  typedstruct module: AddTwitterCount, enforce: true do
    use Domo
    field :id, String.t()
    field :hashtag, String.t()
    field :bucket_end_time, NaiveDateTime.t()
    field :bucket_duration, pos_integer()
    field :count, non_neg_integer()
  end

  typedstruct module: ToggleMonitor, enforce: true do
    use Domo
    field :id, String.t()
    field :account_id, String.t()
    field :monitor_logical_name, String.t()
    field :state, String.t()
  end
end
