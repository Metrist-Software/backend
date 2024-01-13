defmodule Domain.Monitor do
  alias Domain.Helpers
  require Logger

  defstruct [
    :account_id,
    :logical_name,
    :name,
    :analyzer_config,
    :last_report,
    configs: [],
    checks: %{},
    instances: %{},
    errors: [],
    tags: [],
    x_val: nil
  ]

  defmodule Config do
    @derive Jason.Encoder
    # Fairly minimal, just what we need to verify incoming things
    # and emit the correct events.
    defstruct [:id]
  end

  defmodule AnalyzerConfig do
    @derive Jason.Encoder
    defstruct [
      :default_degraded_threshold,
      :instances,
      :check_configs,
      :default_degraded_down_count,
      :default_degraded_up_count,
      :default_degraded_timeout,
      :default_error_timeout,
      :default_error_down_count,
      :default_error_up_count
    ]
  end

  defmodule Check do
    @derive Jason.Encoder
    defstruct [:logical_name, :name, :is_private]
  end

  defmodule Instance do
    @derive Jason.Encoder
    defstruct [:last_report, :check_last_reports]
  end

  defmodule Error do
    @derive Jason.Encoder
    defstruct [:instance_name, :check_logical_name, :message, :time]
  end

  # This is a little bit of a hack until we can figure out how to cleanly serialize
  # state, or maybe turn this into a macro if we like it. We tell Jason to encode
  # our state as a map with an `x_val` key and nothing else, the contents being a
  # base64 encoded representation of the state in Erlang's external term format.
  # Then we tell commanded, which does its best to retrieve the state as the
  # properly typed struct, that we need to add custom decoding - we retrieve the
  # x_val field and deserialize it. Because structs only recognize known keys, we
  # need `x_val` as a field on defstruct above.
  defimpl Jason.Encoder do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          "x_val" => Base.encode64(:erlang.term_to_binary(value))
        },
        opts
      )
    end
  end

  defimpl Commanded.Serialization.JsonDecoder do
    def decode(value) do
      :erlang.binary_to_term(Base.decode64!(value.x_val))
    end
  end

  alias Commanded.Aggregate.Multi
  alias __MODULE__.Commands
  alias __MODULE__.Events
  import Domain.Helpers

  # Command handling

  # Create commands are idempotent but we need one as a first command.
  def execute(%__MODULE__{account_id: nil}, c=%Commands.Create{}) do
    %Domain.Monitor.Events.Created{
      id: c.id,
      account_id: c.account_id,
      monitor_logical_name: c.monitor_logical_name,
      name: c.name || c.monitor_logical_name
    }
  end
  def execute(_monitor, %Commands.Create{}), do: nil

  def execute(monitor, c = %Commands.AddError{}) do
    # monitor_logical_name and account_id should be pulled off of the monitor instance
    # after the maybe_monitor_created as it is not guaranteed to be on the command
    # Anything wanting to use monitor_logical_name or account_id has to be added
    # to the multi to ensure it is available in case the monitor is created on the fly
    monitor
    |> Multi.new()
    |> Multi.execute(&maybe_monitor_created(&1, c.id, monitor.account_id, c.account_id, c.monitor_logical_name))
    |> Multi.execute(&maybe_add_check([c], &1))
    |> Multi.execute(&maybe_add_instances([c], &1, NaiveDateTime.utc_now()))
    |> Multi.execute(&add_error(&1, c))
    |> Multi.execute(&maybe_instance_updated(&1, c))
    |> Multi.execute(&maybe_add_tags(&1, c))
  end

  def execute(monitor, c = %Commands.AddTelemetry{}) do
    # monitor_logical_name and account_id should be pulled off of the monitor instance
    # after the maybe_monitor_created as it is not guaranteed to be on the command
    # Anything wanting to use monitor_logical_name or account_id has to be added
    # to the multi to ensure it is available in case the monitor is created on the fly

    last_report = c.report_time || NaiveDateTime.utc_now()

    monitor
    |> Multi.new()
    |> Multi.execute(&maybe_monitor_created(&1, c.id, monitor.account_id, c.account_id, c.monitor_logical_name))
    |> Multi.execute(&maybe_add_check([c], &1))
    |> Multi.execute(&maybe_add_instances([c], &1, last_report))
    |> Multi.execute(&add_telemetry([c], &1, last_report))
    |> Multi.execute(&maybe_instance_updated(&1, c))
    |> Multi.execute(&maybe_add_tags(&1, c))
  end

  def execute(monitor, c = %Commands.AddConfig{}) do
    monitor
    |> Multi.new()
    |> Multi.execute(&maybe_monitor_created(&1, c.id, monitor.account_id, c.account_id, c.monitor_logical_name))
    |> Multi.execute(&maybe_config_added(&1, c))
  end

  # Everything below this requires a proper Create first.

  def execute(%__MODULE__{account_id: nil}, c) do
    Logger.error("Invalid command on monitor that has not seen a Create: #{inspect c}")
    {:error, :no_create_command_seen}
  end

  def execute(monitor, c = %Commands.UpdateLastReportTime{}) do
    Logger.info("ulrt: monitor is #{inspect monitor}")
    Logger.info("      command is #{inspect c}")
    make_event(monitor, c, Events.LastReportTimeUpdated)
  end

  def execute(monitor, c = %Commands.AddCheck{}) do
    make_event(monitor, c, Events.CheckAdded)
    |> Map.put(:is_private, c.is_private)
  end

  def execute(monitor, c = %Commands.RemoveCheck{}) do
    case Enum.find(monitor.checks, fn {k, _check} -> k == c.check_logical_name end) do
      nil ->
        Logger.info("#{c.id}: Monitor check with id #{c.check_logical_name} not found. new: #{inspect c}")
        nil
      {_logical_name, _check} ->
        make_event(monitor, c, Events.CheckRemoved)
    end
   end

  def execute(%__MODULE__{checks: checks}, %Commands.UpdateCheckName{logical_name: id})
      when not is_map_key(checks, id) do
    {:error, :check_not_found}
  end

  def execute(monitor, c = %Commands.UpdateCheckName{}) do
    make_event(monitor, c, Events.CheckNameUpdated)
  end

  def execute(monitor, c = %Commands.InvalidateEvents{}) do
    make_event(monitor, c, Events.EventsInvalidated)
  end

  def execute(monitor, c = %Commands.InvalidateErrors{}) do
    make_event(monitor, c, Events.ErrorsInvalidated)
  end


  def execute(monitor, c = %Commands.AddInstance{}) do
    make_event(monitor, c, Event.InstanceAdded)
  end

  def execute(monitor, c = %Commands.UpdateInstance{}) do
    make_event(monitor, c, Events.InstanceUpdated)
  end

  def execute(monitor, c = %Commands.RemoveInstance{}) do
    make_event(monitor, c, Events.InstanceRemoved)
  end

  def execute(monitor, c = %Commands.UpdateInstanceCheck{}) do
    make_event(monitor, c, Events.InstanceChckUpdated)
  end

  def execute(monitor, c = %Commands.ToggleMonitor{}) do
    make_event(monitor, c, Events.MonitorToggledEvent)
  end

  def execute(monitor, c = %Commands.RemoveConfig{}) do
    with_existing_config(monitor, c, fn _existing ->
      %Events.ConfigRemoved{
        id: c.id,
        monitor_config_id: c.config_id,
        account_id: monitor.account_id
      }
    end)
  end

  def execute(monitor, c = %Commands.AddAnalyzerConfig{}) do
    new_config = make_analyzer_config(c)
    if new_config != monitor.analyzer_config do
      make_event(monitor, c, Events.AnalyzerConfigAdded)
      |> Map.put(:monitor_name, monitor.name)
    end
  end

  def execute(monitor, c = %Commands.UpdateAnalyzerConfig{}) do
    make_event(monitor, c, Events.AnalyzerConfigUpdated)
  end

  def execute(monitor, c = %Commands.AddEvent{}) do
    make_event(monitor, c, Events.EventAdded)
  end

  def execute(monitor, c = %Commands.EndEvent{}) do
    make_event(monitor, c, Events.EventEnded)
  end

  def execute(monitor, c = %Commands.ClearEvents{}) do
    make_event(monitor, c, Events.EventsCleared)
  end

  def execute(monitor, _ = %Commands.Print{}) do
    IO.inspect(monitor)
    nil
  end


  def execute(monitor, c = %Commands.AddTag{}) do
    if c.tag not in get_tags(monitor) do
      make_event(monitor, c, Events.TagAdded)
    else
      nil
    end
  end

  def execute(monitor, c = %Commands.RemoveTag{}) do
    if c.tag in get_tags(monitor) do
      make_event(monitor, c, Events.TagRemoved)
    else
      nil
    end
  end

  def execute(monitor, c = %Commands.ChangeTag{}) do
    if c.from_tag in get_tags(monitor) do
      make_event(monitor, c, Events.TagChanged)
    else
      nil
    end
  end

  def execute(monitor, c = %Commands.Reset{}) do
    already_reset =
      monitor.analyzer_config == nil &&
      monitor.configs == [] &&
      monitor.checks == %{} &&
      monitor.instances == %{} &&
      monitor.errors == [] &&
      monitor.account_id == nil

    if not already_reset do
      monitor
      |> Multi.new()
      |> Multi.execute(&(remove_analyzer_config(&1, c.id)))
      |> Multi.execute(&(remove_monitor_configs(&1, c.id)))
      |> Multi.execute(&(remove_instances(&1, c.id)))
      |> Multi.execute(&(remove_checks(&1, c.id)))
      |> Multi.execute(&(remove_tags(&1, c.id)))
      |> Multi.execute(fn _ -> %Events.Reset{
        id: c.id
      } end)
    end
  end

  def execute(monitor, c = %Commands.SetExtraConfig{}) do
    with_existing_config(monitor, c, fn _existing ->
      make_event(c, Events.ExtraConfigSet)
      |> Map.put(:account_id, monitor.account_id)
      |> Domain.CryptUtils.encrypt("monitor", id(monitor))
    end)
  end

  def execute(monitor, c = %Commands.SetRunSpec{}) do
    with_existing_config(monitor, c, fn _existing ->
      make_event(c, Events.RunSpecSet)
      |> Map.put(:account_id, monitor.account_id)
    end)
  end

  def execute(monitor, c = %Commands.SetSteps{}) do
    with_existing_config(monitor, c, fn _existing ->
      make_event(monitor, c, Events.StepsSet)
    end)
  end

  def execute(monitor, c = %Commands.SetRunGroups{}) do
    with_existing_config(monitor, c, fn _existing ->
      %Events.RunGroupsSet{
        id: c.id,
        config_id: c.config_id,
        run_groups: c.run_groups,
        account_id: monitor.account_id
      }
    end)
  end

  def execute(monitor, c = %Commands.SetIntervalSecs{}) do
    with_existing_config(monitor, c, fn _existing ->
      %Events.IntervalSecsSet{
        id: c.id,
        config_id: c.config_id,
        interval_secs: c.interval_secs,
        account_id: monitor.account_id
      }
    end)
  end

  def execute(monitor, c = %Commands.ChangeName{}) do
    make_event(monitor, c, Events.NameChanged)
  end

  def execute(monitor, c = %Commands.SetTwitterHashtags{}) do
    make_event(monitor, c, Events.TwitterHashtagsSet)
  end

  def execute(monitor, c = %Commands.AddTwitterCount{}) do
    make_event(monitor, c, Events.TwitterCountAdded)
  end

  defp with_existing_config(monitor, command, function) do
    case Enum.find(monitor.configs, fn cfg -> cfg.id == command.config_id end) do
      nil ->
        raise ArgumentError, "#{command.id}: monitor config with id #{command.config_id || "<nil>"} unknown (known: #{inspect monitor.configs})"
      existing_config ->
        function.(existing_config)
    end
  end

  # Event handling

  @spec apply(any, %{:__struct__ => atom, optional(any) => any}) :: any
  def apply(monitor, e = %Events.Created{}) do
    %__MODULE__{
      monitor
      | logical_name: e.monitor_logical_name,
        account_id: e.account_id
    }
  end

  def apply(monitor, e = %Events.Updated{}) do
    %__MODULE__{
      monitor
      | logical_name: e.monitor_logical_name,
        name: e.name,
        account_id: e.account_id
    }
  end

  def apply(monitor, e = %Events.CheckAdded{}) do
    %__MODULE__{
      monitor
      | checks:
          Map.put(
            monitor.checks,
            e.logical_name,
            %Check{
              logical_name: e.logical_name,
              name: e.name,
              is_private: e.is_private
            }
          )
    }
  end

  def apply(monitor, e = %Events.CheckRemoved{}) do
    %__MODULE__{
      monitor
      | checks: Enum.reject(monitor.checks, fn {k, _} -> k == e.check_logical_name end) |> Map.new()
    }
  end

  def apply(monitor, e = %Events.CheckNameUpdated{}) do
    %__MODULE__{
      monitor
      | checks:
          Map.put(
            monitor.checks,
            e.logical_name,
            Map.put(monitor.checks[e.logical_name], :name, e.name)
          )
    }
  end

  def apply(monitor, e = %Events.InstanceAdded{}) do
    %__MODULE__{
      monitor
      | instances:
          Map.put(
            monitor.instances,
            e.instance_name,
            %Instance{
              last_report: e.last_report,
              check_last_reports: e.check_last_reports
            }
          )
    }
  end

  def apply(monitor, e = %Events.InstanceRemoved{}) do
    %__MODULE__{
      monitor
      | instances: Enum.reject(monitor.instances, fn {k, _} -> k == e.instance_name end) |> Map.new()
    }
  end

  def apply(monitor, e = %Events.TelemetryAdded{}) do
    # Deliberately not storing telemetry in state but have to update these other state fields
    monitor
    |> update_instance(e.instance_name, e.created_at)
    |> update_instance_check(e.instance_name, e.check_logical_name, e.created_at)
    |> update_monitor_last_report(e.created_at)
  end

  def apply(monitor, e = %Events.InstanceUpdated{}), do: update_instance(monitor, e.instance_name, e.last_report)
  def apply(monitor, e = %Events.InstanceCheckUpdated{}), do: update_instance_check(monitor, e.instance_name, e.check_logical_name, e.last_report)
  def apply(monitor, e = %Events.LastReportTimeUpdated{}), do: update_monitor_last_report(monitor, e.last_report)

  def apply(monitor, e = %Events.ConfigAdded{}) do
    %__MODULE__{
      monitor
      | configs: [
          %Config{
            id: config_id_of(e)
          }
          | monitor.configs
        ]
    }
  end

  def apply(monitor, e = %Events.ConfigRemoved{}) do
    %__MODULE__{
      monitor
      | configs: Enum.reject(monitor.configs, &(&1.id == e.monitor_config_id))
    }
  end

  def apply(monitor, e = %Events.AnalyzerConfigAdded{}) do
    %__MODULE__{monitor | analyzer_config: make_analyzer_config(e)}
  end

  def apply(monitor, e = %Events.AnalyzerConfigUpdated{}) do
    %__MODULE__{monitor | analyzer_config: make_analyzer_config(e)}
  end

  def apply(monitor, %Events.AnalyzerConfigRemoved{}) do
    %__MODULE__{monitor | analyzer_config: nil}
  end

  def apply(monitor, e = %Events.TagAdded{}) do
    Map.put(monitor, :tags, [e.tag | get_tags(monitor)])
  end

  def apply(monitor, e = %Events.TagRemoved{}) do
    Map.put(monitor, :tags, List.delete(get_tags(monitor), e.tag))
  end

  def apply(monitor, e = %Events.TagChanged{}) do
    new_tags = monitor
    |> get_tags()
    |> List.delete(e.from_tag)
    |> List.insert_at(0, e.to_tag)
    Map.put(monitor, :tags, new_tags)
  end

  def apply(monitor, %Events.Reset{}) do
    %__MODULE__{
      monitor
      | analyzer_config: nil,
        configs: [],
        checks: %{},
        instances: %{},
        errors: [],
        # This is reset to prompt re-adding the monitor if new telemetry comes in.
        # Mostly helpful for private monitors that may get re-added automatically.
        # TODO: probably a bad heuristic to use, we should make this more explicit
        # in the future.
        account_id: nil
    }
  end

  def apply(monitor, _ = %Events.MonitorToggledEvent{}) do
    monitor
  end

  # In case logic is needed here, see `config_id_of` for how to deal with old events
  def apply(monitor, _ = %Events.ErrorAdded{}) do
    monitor
  end

  # In case logic is needed here, see `config_id_of` for how to deal with old events
  def apply(monitor, _ = %Events.EventAdded{}) do
    monitor
  end

  def apply(monitor, _ = %Events.EventEnded{}) do
    monitor
  end

  def apply(monitor, _ = %Events.EventsCleared{}) do
    Logger.warn("Domain.Monitor.Events.EventsCleared is deprecated. Events should be cleared by applying the appropriate EventEnded and and EventAdded events")

    monitor
  end

  def apply(monitor, _ = %Events.EventsInvalidated{}) do
    monitor
  end


  def apply(monitor, _ = %Events.ErrorsInvalidated{}) do
    monitor
  end

  # In case logic is needed here, see `config_id_of` for how to deal with old events
  def apply(monitor, _ = %Events.ExtraConfigSet{}) do
    monitor
  end

  # In case logic is needed here, see `config_id_of` for how to deal with old events
  def apply(monitor, _ = %Events.RunGroupsSet{}) do
    monitor
  end

  # In case logic is needed here, see `config_id_of` for how to deal with old events
  def apply(monitor, _ = %Events.RunSpecSet{}) do
    monitor
  end

  # In case logic is needed here, see `config_id_of` for how to deal with old events
  def apply(monitor, _ = %Events.StepsSet{}) do
    monitor
  end

  def apply(monitor, _ = %Events.IntervalSecsSet{}) do
    monitor
  end

  def apply(monitor, %Events.NameChanged{name: name}) do
    %__MODULE__{monitor | name: name}
  end

  def apply(monitor, _ = %Events.TwitterHashtagsSet{}) do
    monitor
  end

  def apply(monitor, _ = %Events.TwitterCountAdded{}) do
    monitor
  end

  defp maybe_add_instances(params, monitor, last_report) do
    params
    |> Enum.filter(fn p -> !Map.has_key?(monitor.instances, p.instance_name) end)
    |> Enum.map(fn p ->
        event = %Domain.Monitor.Events.InstanceAdded{
          id: p.id,
          account_id: monitor.account_id,
          monitor_logical_name: monitor.logical_name,
          instance_name: p.instance_name,
          last_report: last_report,
          check_last_reports: %{}
        }
        analyzer_config = monitor.analyzer_config
        # Automatically start tracking new instances.
        cond do
          is_nil(monitor.analyzer_config) ->
            [event, %Events.AnalyzerConfigAdded{
              id: p.id,
              account_id: monitor.account_id,
              monitor_logical_name: monitor.logical_name,
              default_degraded_threshold: 5.0,
              instances: [p.instance_name],
              check_configs: []
            }]
          p.instance_name not in analyzer_config.instances and analyzer_config.instances != [] ->
            # TODO split up analyzer config events into individual changes, this is not
            # really helpful.
            # Note that this will never be called on create, so it is safe to use the
            # monitor values in this instance.
            [event, %Events.AnalyzerConfigUpdated{
                id: id(monitor),
                account_id: monitor.account_id,
                monitor_logical_name: monitor.logical_name,
                default_degraded_threshold: monitor.analyzer_config.default_degraded_threshold,
                instances: [p.instance_name | monitor.analyzer_config.instances],
                check_configs: monitor.analyzer_config.check_configs,
                default_degraded_down_count: monitor.analyzer_config.default_degraded_down_count,
                default_degraded_up_count: monitor.analyzer_config.default_degraded_up_count,
                default_degraded_timeout: monitor.analyzer_config.default_degraded_timeout,
                default_error_timeout: monitor.analyzer_config.default_error_timeout,
                default_error_down_count: monitor.analyzer_config.default_error_down_count,
                default_error_up_count: monitor.analyzer_config.default_error_up_count
              }]
            true ->
              event
        end
    end)
    |> List.flatten()
  end

  defp maybe_add_check(params, monitor) do
    Enum.map(params, fn p ->
      if !Map.has_key?(monitor.checks, p.check_logical_name) do
        %Domain.Monitor.Events.CheckAdded{
          id: p.id,
          account_id: monitor.account_id,
          monitor_logical_name: monitor.logical_name,
          logical_name: p.check_logical_name,
          name: p.check_logical_name,
          is_private: p.is_private
        }
      end
    end)
    |> Enum.reject(fn e -> is_nil(e) end)
  end

  defp add_error(monitor, command) do
    # Commenting this as this seems odd. Command has been updated to send :report_time
    # but the pre-existing event simply has a field named "time"
    make_event(monitor, command, Events.ErrorAdded)
    |> Map.delete(:report_time)
    |> Map.put(:time, command.report_time)
  end

  defp add_telemetry(params, monitor, last_report) do
    Enum.map(params, fn p ->
      %Domain.Monitor.Events.TelemetryAdded{
        id: p.id,
        account_id: monitor.account_id,
        monitor_logical_name: monitor.logical_name,
        check_logical_name: p.check_logical_name,
        instance_name: p.instance_name,
        is_private: p.is_private,
        value: p.value,
        metadata: p.metadata,
        created_at: last_report
      }
    end)
  end

  defp maybe_monitor_created(_monitor, id, current_account_id, intended_account_id, monitor_logical_name) do
    if is_nil(current_account_id) do
      if is_nil(intended_account_id) do
        raise ArgumentError, message: "Account id was nil on new monitor, cannot create."
      end
      if is_nil(monitor_logical_name) do
        raise ArgumentError, message: "Monitor logical name was nil on new monitor, cannot create."
      end
      %Domain.Monitor.Events.Created{
        id: id,
        account_id: intended_account_id,
        monitor_logical_name: monitor_logical_name
      }
    end
  end

  defp maybe_config_added(monitor, c = %Commands.AddConfig{}) do
    case Enum.find(monitor.configs, fn cfg -> cfg.id == c.config_id end) do
      nil ->
        monitor
        |> make_event(c, Events.ConfigAdded)
        |> Domain.CryptUtils.encrypt("monitor", id(monitor))
      cfg ->
        Logger.info("#{c.id}: duplicate config added, ignoring. Had: #{inspect cfg}, new: #{inspect c}")
        nil
    end
  end

  defp maybe_instance_updated(monitor, c = %kind{}) when kind in [Commands.AddError, Commands.AddTelemetry] do
    if Map.has_key?(monitor.instances, c.instance_name) do
      [
        %Events.InstanceUpdated{
          id: c.id,
          account_id: monitor.account_id,
          monitor_logical_name: monitor.logical_name,
          instance_name: c.instance_name,
          last_report: c.report_time
        },
        %Events.InstanceCheckUpdated{
          id: c.id,
          account_id: monitor.account_id,
          monitor_logical_name: monitor.logical_name,
          instance_name: c.instance_name,
          check_logical_name: c.check_logical_name,
          last_report: c.report_time
        }
      ]
    end
  end

  defp maybe_add_tags(monitor, c) do
    c =
      if is_nil(Map.get(c, :metadata, %{})) do
        Map.put(c, :metadata, %{})
      else
        c
      end

    c
    |> Map.get(:metadata, %{})
    |> Enum.filter(fn {k, _v} -> known_tag?(k) end)
    |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
    |> Enum.filter(fn tag -> tag not in get_tags(monitor) end)
    |> Enum.map(fn tag ->
      %Domain.Monitor.Events.TagAdded{
        id: c.id,
        account_id: monitor.account_id,
        monitor_logical_name: monitor.logical_name,
        tag: tag
      }
    end)
  end

  # KISS for now, we only have one Officially Known Tag
  defp known_tag?(tag), do: tag in ["metrist.source", "metrist.beta"]

  defp remove_analyzer_config(monitor, id) do
    if not is_nil(monitor.analyzer_config) do
      %Events.AnalyzerConfigRemoved{
        id: id,
        account_id: monitor.account_id,
        monitor_logical_name: monitor.logical_name
      }
    end
  end

  defp remove_monitor_configs(monitor, id) do
    Enum.map(monitor.configs, fn cfg ->
      %Events.ConfigRemoved{
        id: id,
        account_id: monitor.account_id,
        monitor_config_id: cfg.id
      }
    end)
   end

  defp remove_instances(monitor, id) do
    Enum.map(monitor.instances, fn {instance_name, _instance} ->
      %Events.InstanceRemoved{
        id: id,
        account_id: monitor.account_id,
        monitor_logical_name: monitor.logical_name,
        instance_name: instance_name
      }
    end)
  end

  defp remove_checks(monitor, id) do
    Enum.map(monitor.checks, fn {check_id, _instance} ->
      %Events.CheckRemoved{
        id: id,
        account_id: monitor.account_id,
        monitor_logical_name: monitor.logical_name,
        check_logical_name: check_id
      }
    end)
  end

  defp remove_tags(monitor, id) do
    Enum.map(get_tags(monitor), fn tag ->
      %Events.TagRemoved{
        id: id,
        account_id: monitor.account_id,
        monitor_logical_name: monitor.logical_name,
        tag: tag
      }
    end)
  end

  defp update_instance(monitor, instance_name, last_report) do
    instance = Map.get(monitor.instances, instance_name)
    updated_instance = %Instance{instance | last_report: last_report}
    instances = Map.put(monitor.instances, instance_name, updated_instance)

    %__MODULE__{
      monitor
      | instances: instances
    }
  end

  defp update_instance_check(monitor, instance_name, check_logical_name, last_report) do
    instance = Map.get(monitor.instances, instance_name)
    updated_checks = Map.put(instance.check_last_reports, check_logical_name, last_report)
    updated_instance = %Instance{instance | check_last_reports: updated_checks}
    instances = Map.put(monitor.instances, instance_name, updated_instance)

    %__MODULE__{
      monitor
      | instances: instances
    }
  end

  defp update_monitor_last_report(monitor, last_report) do
    %__MODULE__{
      monitor
      | last_report: last_report
    }
  end

  def make_analyzer_config(event_or_command) do
    %AnalyzerConfig{
      default_degraded_threshold: event_or_command.default_degraded_threshold,
      instances: event_or_command.instances,
      check_configs: event_or_command.check_configs,
      default_degraded_down_count: event_or_command.default_degraded_down_count,
      default_degraded_up_count: event_or_command.default_degraded_up_count,
      default_degraded_timeout: event_or_command.default_degraded_timeout,
      default_error_timeout: event_or_command.default_error_timeout,
      default_error_down_count: event_or_command.default_error_down_count,
      default_error_up_count: event_or_command.default_error_up_count
    }
  end

  # A lot of command/events pair follow the pattern where we put the account id
  # and monitor logical name in the event.
  defp make_event(monitor, command, event_type) do
    command
    |> make_event(event_type)
    |> Map.put(:account_id, monitor.account_id)
    |> Map.put(:monitor_logical_name, monitor.logical_name)
  end

  @doc """
  Initially, we confusingly emitted events with having the `id` field
  set not to our `id` but to the id of the monitor configuration. This has been
  corrected by adding the `config_id` field to corresponding events and commands.
  When replaying events, this means that the actual config id can be in two places,
  which we account for with this helper method.

  The same issue holds for EventAdded/ErrorAdded and the events that work on embedded
  fields of the monitor configuration (RunSpec, ExtraConfig, Steps). Currently, we have
  no business logic on the event handling side for these but if that changes, this or a
  similar function for events/errors needs to be used to get the unique id of the object.

  The functions should be used wherever these ids are needed, like projections.
  """
  def config_id_of(e = %Events.ConfigAdded{}), do: Helpers.id_of(e, :config_id)
  def config_id_of(e = %Events.ExtraConfigSet{}), do: Helpers.id_of(e, :config_id)
  def config_id_of(e = %Events.RunGroupsSet{}), do: Helpers.id_of(e, :config_id)
  def event_id_of(e = %Events.EventAdded{}), do: Helpers.id_of(e, :event_id)
  def error_id_of(e = %Events.ErrorAdded{}), do: Helpers.id_of(e, :error_id)

  defp id(mon) do
    "#{mon.account_id}_#{mon.logical_name}"
  end

  # Cannot access tags through monitor.tags since
  # older aggregates might not have a "tags" in their struct.
  # "tags" was added to the aggregate after many of them were already created
  # and currently rebuilding the monitor aggregates is prohibitive because
  # of the TelementryAdded events.
  defp get_tags(monitor) do
    Map.get(monitor, :tags, [])
  end
end
