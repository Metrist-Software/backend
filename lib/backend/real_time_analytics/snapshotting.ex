defmodule Backend.RealTimeAnalytics.Snapshotting do
  @moduledoc """
  Provides functionality for building and updating Snapshots
  """

  use TypedStruct

  @type state :: Backend.Projections.Dbpa.Snapshot.state()
  @type mci :: {binary(), binary(), binary(), binary()}
  @type telemetry :: {NaiveDateTime.t(), float()}

  @min_date_time ~N[1970-01-01 00:00:00]
  @max_check_details_age_hours 24

  # Changes from existing snapshots:
  #  - States are atoms instead of strings
  #  - Ignoring redundent fields
  #  - Snapshot ID is from Domain.Id instead of the monitor logical name

  # TODO: Handle no recent data
  # TODO: Maybe precalc length of telemetry to avoid length() calls in guards

  alias Backend.Projections.Dbpa.{Monitor, MonitorCheck, AnalyzerConfig}
  alias Backend.Projections.Dbpa.CheckConfig
  alias Backend.Projections.Dbpa.StatusPage.ComponentChange
  alias Backend.Projections.Dbpa.Snapshot.Snapshot
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail
  alias Backend.RealTimeAnalytics.MCIProcess

  @doc """
  Builds a full initial snapshot. For subsequent realtime updates, use `update_snapshot/7`.

  monitor should have it's `checks` field preloaded in order to pull check names
  """
  @spec build_full_snapshot(
          list({mci(), list(telemetry()), float(), list(MCIProcess.error())}),
          [{binary(), ComponentChange.t()}],
          %AnalyzerConfig{},
          %Monitor{},
          [binary()]
        ) :: Snapshot.t()
  def build_full_snapshot(
        telemetry_by_mci,
        sp_component_changes,
        analyzer_config,
        monitor,
        run_steps,
        corr_id \\ nil
      ) do
    check_details =
      Enum.filter(telemetry_by_mci, fn {mci, _telemetry, _average, _errors} ->
        should_include_mci(mci, analyzer_config)
      end)
      |> Enum.map(fn {mci, telemetry, average, errors} ->
        evaluate_check_instance(
          telemetry,
          average,
          errors,
          :up,
          mci,
          get_check_config_for_mci(analyzer_config, mci),
          monitor
        )
      end)

    telemetry_by_ci =
      Enum.group_by(telemetry_by_mci, fn {mci, _telemetry, _average, _errors} ->
        {_a, _m, c, i} = mci
        {c, i}
      end)

    blocked_steps =
      Enum.filter(check_details, &(&1.state == :down))
      |> Enum.flat_map(&Map.get(telemetry_by_ci, {&1.check_id, &1.instance}, []))
      |> Enum.flat_map(fn {mci, _telemetry, _average, errors} ->
        get_blocked_steps(mci, errors)
      end)
      |> MapSet.new()

    %Snapshot{
      id: Domain.Id.new(),
      monitor_id: monitor.logical_name,
      check_details: check_details,
      last_updated: NaiveDateTime.utc_now()
    }
    |> set_status_page_component_check_details(sp_component_changes)
    |> set_snapshot_last_checked()
    |> maybe_set_blocked_steps(blocked_steps, monitor)
    |> set_snapshot_state()
    |> remove_stale_check_details()
    |> remove_duplicate_check_details()
    |> order_check_details(run_steps)
    |> set_snapshot_message(monitor.name)
    |> set_correlation_id()
    |> pass_outstanding_corr_id(corr_id)
  end

  @doc """
  Update an existing Snapshot with data for a given mci
  """
  @spec update_snapshot(
          Snapshot.t(),
          mci(),
          list(telemetry()),
          float(),
          list(MCIProcess.error()),
          %AnalyzerConfig{},
          nil | %Monitor{},
          [binary()]
        ) :: Snapshot.t()
  def update_snapshot(
        existing_snapshot,
        mci,
        telemetry,
        average,
        errors,
        analyzer_config,
        monitor,
        run_steps
      ) do
    case should_include_mci(mci, analyzer_config) do
      false ->
        existing_snapshot

      true ->
        existing_check_detail =
          existing_snapshot.check_details
          |> Enum.find(fn %CheckDetail{check_id: check_id, instance: instance} ->
            check_id == mci_field(mci, :check) && instance == mci_field(mci, :instance)
          end)

        existing_check_state =
          case existing_check_detail do
            %CheckDetail{state: state} -> state
            _ -> :up
          end

        check_config = get_check_config_for_mci(analyzer_config, mci)

        check_detail =
          evaluate_check_instance(
            telemetry,
            average,
            errors,
            existing_check_state,
            mci,
            check_config,
            monitor
          )

        blocked_steps =
          if check_detail.state == :down do
            get_blocked_steps(mci, errors)
          else
            []
          end
          |> MapSet.new()

        status_page_component_check_details =
          if existing_snapshot do
            existing_snapshot.status_page_component_check_details
          end

        %Snapshot{
          id: existing_snapshot.id,
          monitor_id: existing_snapshot.monitor_id,
          check_details: get_updated_check_details(existing_snapshot.check_details, check_detail),
          last_updated: NaiveDateTime.utc_now(),
          status_page_component_check_details: status_page_component_check_details
        }
        |> set_snapshot_last_checked()
        |> maybe_set_blocked_steps(blocked_steps, monitor)
        |> set_snapshot_state()
        |> remove_stale_check_details()
        |> remove_duplicate_check_details()
        |> order_check_details(run_steps)
        |> set_snapshot_message(monitor.name)
        |> set_correlation_id(existing_snapshot)
    end
  end

  def remove_duplicate_check_details(snapshot) do
    # In rare race conditions, we may temporarily have duplicate MCI processes on the first build_full_snapshot
    # until Swarm kills the duplicates. Swarm is eventually consistent so we have to handle that case.
    # The duplicate MCI will mean that we have more than one check detail generated for a given check_id and instance.
    # Those duplicate check_details will keep being passed off through state handoff and only update_snapshot
    # will continue to get called. update_snapshot will only update the first matching detail it finds in the list
    # as it correctly assumes there should be only one so let's clean them up. Search for check details
    # with the same instance and check_id and remove the oldest one. This will also have the benefit of cleaning up
    # the ones already stuck in this state. In most cases this will end up changing nothing
    deduped_check_details =
      snapshot.check_details
      |> Enum.reduce([], fn snapshot_detail, acc ->
        # check if acc already has one with the same check_id and instance
        # if it does, compare the last_checked and keep the one with the highest value
        # if it doesnt, simply add it to acc
        existing_accumulator_detail =
          Enum.find(acc, fn accumulator_detail ->
            accumulator_detail.check_id == snapshot_detail.check_id &&
              accumulator_detail.instance == snapshot_detail.instance
          end)

        if existing_accumulator_detail do
          with true <-
                 existing_accumulator_detail.last_checked != nil &&
                   snapshot_detail.last_checked != nil,
               :gt <-
                 NaiveDateTime.compare(
                   snapshot_detail.last_checked,
                   existing_accumulator_detail.last_checked
                 ) do
            index =
              Enum.find_index(acc, fn accumulator_detail ->
                existing_accumulator_detail == accumulator_detail
              end)

            List.replace_at(acc, index, snapshot_detail)
          else
            _ -> acc
          end
        else
          # Doesn't exists in the accumulator, add it
          [snapshot_detail | acc]
        end
      end)

    # This process would have reversed the list, so for consistency reverse it back
    %Snapshot{snapshot | check_details: Enum.reverse(deduped_check_details)}
  end

  defp maybe_set_blocked_steps(snapshot, blocked_steps, monitor) do
    if Backend.config([Backend.RealTimeAnalytics, :enable_blocked_check_details_state]) do
      set_blocked_steps(snapshot, blocked_steps, monitor)
    else
      snapshot
    end
  end

  def set_blocked_steps(snapshot, blocked_steps, monitor) when blocked_steps != %MapSet{} do
    check_details =
      Enum.map(snapshot.check_details, fn cd ->
        if MapSet.member?(blocked_steps, {cd.instance, cd.check_id}) do
          check_name = get_check_name(cd.check_id, monitor)
          %{cd | state: :blocked, message: "#{check_name} is currently blocked by a failure in a previous step in #{cd.instance}."}
        else
          cd
        end
      end)

    %{snapshot | check_details: check_details}
  end

  def set_blocked_steps(snapshot, _blocked_steps, _monitor), do: snapshot

  @spec get_updated_check_details(list(CheckDetail.t()), CheckDetail.t()) :: list(CheckDetail.t())
  def get_updated_check_details(existing_details, new_detail) do
    existing_index =
      Enum.find_index(existing_details, fn detail ->
        detail.check_id == new_detail.check_id and detail.instance == new_detail.instance
      end)

    case existing_index do
      nil -> [new_detail | existing_details]
      i -> List.replace_at(existing_details, i, new_detail)
    end
  end

  # Snapshotting Logic

  @spec evaluate_check_instance(
          list(telemetry()),
          float(),
          list(MCIProcess.error()),
          state(),
          mci(),
          CheckConfig.t(),
          nil | %Monitor{}
        ) :: CheckDetail.t()
  def evaluate_check_instance(
        telemetry,
        telemetry_average,
        errors,
        previous_state,
        mci,
        config,
        monitor
      ) do
    # TODO: Maybe sort descending? Would prevent having to do full list scans for taking from end
    # Though if it's just the last hour of telemetry, we're only looking at a list with ~30 entries
    telemetry = Enum.sort_by(telemetry, fn {time, _value} -> time end, {:asc, NaiveDateTime})
    errors = Enum.sort_by(errors, fn {time, _value} -> time end, {:asc, NaiveDateTime})

    {last_telem_time, last_telem_value} =
      case List.last(telemetry) do
        {time, value} -> {time, value}
        _ -> {@min_date_time, nil}
      end

    {last_error_time, _} =
      errors
      |> List.last({@min_date_time, nil})

    last_data_time =
      case NaiveDateTime.compare(last_telem_time, last_error_time) do
        :gt -> last_telem_time
        _ -> last_error_time
      end

    check_id = mci_field(mci, :check)

    check_name = get_check_name(check_id, monitor)

    details = %CheckDetail{
      check_id: check_id,
      average: telemetry_average,
      instance: mci_field(mci, :instance),
      name: check_name,
      last_checked: last_data_time,
      current: last_telem_value,
      created_at: NaiveDateTime.utc_now()
    }

    {state, message} =
      cond do
        is_check_down?(telemetry, telemetry_average, errors, previous_state, config) ->
          {:down,
           "#{details.name} is not currently responding from #{details.instance} and is currently down."}

        is_timed_out?(telemetry, errors, config.error_timeout, config.error_down_count) ->
          {:down,
           "#{details.name} timed out after the error timeout threshold of #{config.error_timeout} seconds."}

        is_timed_out?(telemetry, errors, config.degraded_timeout, config.degraded_down_count) ->
          {:degraded,
           "#{details.name} timed out after the warning timeout threshold of #{config.degraded_timeout} seconds."}

        is_check_degraded?(telemetry, telemetry_average, errors, previous_state, config) ->
          percent_slower = round((details.current - details.average) / details.average * 100)

          {:degraded,
           "#{details.name} is about #{percent_slower}% slower than normal from #{details.instance} and is currently degraded."}

        true ->
          {:up, "#{details.name} is responding normally from #{details.instance}"}
      end

    # Finalize check details
    details
    |> Map.put(:state, state)
    |> Map.put(:message, message)
  end

  ## Checking for down state

  @spec is_check_down?(
          list(telemetry()),
          float(),
          list(MCIProcess.error()),
          state(),
          CheckConfig.t()
        ) :: boolean()
  def is_check_down?(telemetry, average, errors, previous_state, config) do
    has_recent_errors?(telemetry, errors, config) ||
      (is_down_and_cannot_be_up_yet?(telemetry, average, errors, previous_state, config) &&
         is_down_and_cannot_be_degraded_yet?(telemetry, errors, previous_state, config))
  end

  @spec has_recent_errors?(list(telemetry()), list(MCIProcess.error()), CheckConfig.t()) ::
          boolean()
  def has_recent_errors?(_telemetry, errors, config)
      when length(errors) < config.error_down_count,
      do: false

  def has_recent_errors?(telemetry, errors, config) do
    time_of_last_success =
      case List.last(telemetry) do
        {time, _value} -> time
        _ -> @min_date_time
      end

    Enum.take(errors, -config.error_down_count)
    |> Enum.all?(fn {time, _error_string} ->
      NaiveDateTime.compare(time, time_of_last_success) == :gt
    end)
  end

  @spec is_down_and_cannot_be_up_yet?(
          list(telemetry()),
          float(),
          list(MCIProcess.error()),
          state(),
          CheckConfig.t()
        ) :: boolean()
  def is_down_and_cannot_be_up_yet?(_telemetry, _average, _errors, previous_state, _config)
      when previous_state != :down,
      do: false

  def is_down_and_cannot_be_up_yet?(telemetry, _average, _errors, _previous_state, config)
      when length(telemetry) < config.error_up_count,
      do: true

  def is_down_and_cannot_be_up_yet?(telemetry, average, errors, _previous_state, config) do
    time_of_last_error =
      case List.last(errors) do
        {time, _error_string} -> time
        _ -> @min_date_time
      end

    # Specifically check degraded_threshold in down condition to not jump from down to up when receiving degraded telemetry
    degraded_value = average * config.degraded_threshold

    Enum.take(telemetry, -config.error_up_count)
    |> Enum.any?(fn {time, value} ->
      NaiveDateTime.compare(time, time_of_last_error) == :lt ||
        value > degraded_value
    end)
  end

  @spec is_down_and_cannot_be_degraded_yet?(
          list(telemetry()),
          list(MCIProcess.error()),
          state(),
          CheckConfig.t()
        ) :: boolean()
  def is_down_and_cannot_be_degraded_yet?(_telemetry, _errors, previous_state, _config)
      when previous_state != :down,
      do: false

  def is_down_and_cannot_be_degraded_yet?(telemetry, _errors, _previous_state, config)
      when length(telemetry) < config.degraded_down_count,
      do: true

  def is_down_and_cannot_be_degraded_yet?(telemetry, errors, _previous_state, config) do
    time_of_last_error =
      case List.last(errors) do
        {time, _error_string} -> time
        _ -> @min_date_time
      end

    Enum.take(telemetry, -config.degraded_down_count)
    |> Enum.any?(fn {time, _value} ->
      NaiveDateTime.compare(time, time_of_last_error) == :lt
    end)
  end

  ## Checking for degraded state

  @spec is_check_degraded?(
          list(telemetry()),
          float(),
          list(MCIProcess.error()),
          state(),
          CheckConfig.t()
        ) :: boolean()
  def is_check_degraded?(_telemetry, _average, _errors, _previous_state, config)
      when config.degraded_threshold == 0.0,
      do: false

  def is_check_degraded?(telemetry, average, errors, previous_state, config) do
    # This depends on already knowing that we can't be currently down from previously calling is_check_down?()
    has_recent_above_threshold?(
      telemetry,
      average,
      config.degraded_threshold,
      config.degraded_down_count
    ) ||
      is_degraded_and_cannot_be_up_yet?(telemetry, average, previous_state, config) ||
      is_down_and_cannot_be_up_yet?(telemetry, average, errors, previous_state, config)
  end

  @spec is_degraded_and_cannot_be_up_yet?(list(telemetry()), float(), state(), CheckConfig.t()) ::
          boolean()
  def is_degraded_and_cannot_be_up_yet?(_telemetry, _average, previous_state, _config)
      when previous_state != :degraded,
      do: false

  def is_degraded_and_cannot_be_up_yet?(telemetry, _average, _previous_state, config)
      when length(telemetry) < config.degraded_up_count,
      do: true

  def is_degraded_and_cannot_be_up_yet?(_telemetry, average, _previous_state, _config)
      when is_nil(average),
      do: false

  def is_degraded_and_cannot_be_up_yet?(telemetry, average, _previous_state, config) do
    degraded_value = average * config.degraded_threshold

    Enum.take(telemetry, -config.degraded_up_count)
    |> Enum.any?(fn {_time, value} -> value > degraded_value end)
  end

  ## Generic functions
  @spec has_recent_above_threshold?(list(telemetry()), float(), integer(), integer()) :: boolean()
  def has_recent_above_threshold?(telemetry, _average, _threshold, count)
      when length(telemetry) < count,
      do: false

  def has_recent_above_threshold?(_telemetry, average, _threshold, _count)
      when is_nil(average),
      do: false

  def has_recent_above_threshold?(telemetry, average, threshold, count) do
    threshold_value = average * threshold

    Enum.take(telemetry, -count)
    |> Enum.all?(fn {_time, value} ->
      value > threshold_value
    end)
  end

  @spec is_timed_out?(list(telemetry()), list(MCIProcess.error()), integer(), integer()) ::
          boolean()
  def is_timed_out?(telemetry, _errors, _timeout, down_count) when length(telemetry) < down_count,
    do: false

  def is_timed_out?(telemetry, errors, timeout, down_count) do
    last_error = List.last(errors)
    last_telemetry = List.last(telemetry)

    is_last_error_before_last_telemetry =
      case {last_error, last_telemetry} do
        {nil, _} -> true
        {_, nil} -> false
        {{t1, _error_string}, {t2, _value}} -> NaiveDateTime.compare(t1, t2) == :lt
      end

    last_n_telems_timed_out =
      Enum.take(telemetry, -down_count)
      |> Enum.all?(fn {_time, value} -> value > timeout end)

    is_last_error_before_last_telemetry && last_n_telems_timed_out
  end

  ## Snapshot building helpers

  @spec set_snapshot_last_checked(Snapshot.t()) :: Snapshot.t()
  def set_snapshot_last_checked(snapshot) do
    last_checked =
      case Enum.max_by(snapshot.check_details, & &1.last_checked, NaiveDateTime, fn -> nil end) do
        %CheckDetail{last_checked: last_checked} -> last_checked
        _ -> @min_date_time
      end

    %Snapshot{snapshot | last_checked: last_checked}
  end

  @spec set_snapshot_state(Snapshot.t()) :: Snapshot.t()
  def set_snapshot_state(snapshot) do
    state =
      Enum.reduce(
        snapshot.check_details,
        {:up, true},
        fn %CheckDetail{state: state}, {worst_state, all_down} ->
          new_all_down = all_down && state in [:down, :blocked]
          new_worst_state = Backend.Projections.Dbpa.Snapshot.get_worst_state(state, worst_state)

          {new_worst_state, new_all_down}
        end
      )
      |> case do
        # Every CheckDetail state was :down or :blocked
        {:down, true} -> :down
        # At least 1 CheckDetail state was :down
        {:down, false} -> :issues
        # Snapshots cannot be blocked even if that is the "worst" state in the check details. Set to issues
        {:blocked, _} -> :issues
        # Worst state was something else
        {state, _} -> state
      end

    %Snapshot{snapshot | state: state}
  end

  @spec set_snapshot_message(Snapshot.t(), String.t()) :: Snapshot.t()
  def set_snapshot_message(snapshot = %Snapshot{state: state}, monitor_name) do
    message =
      case state do
        :up -> "#{monitor_name} is operating normally in all monitored regions across all checks."
        :degraded -> "#{monitor_name} is in a degraded state."
        :issues -> "#{monitor_name} is experiencing issues."
        :down -> "#{monitor_name} is in a down state for all checks in all regions."
        _ -> ""
      end

    %Snapshot{snapshot | message: message}
  end

  @spec should_include_mci(mci(), %AnalyzerConfig{}) :: boolean()
  def should_include_mci(mci, analyzer_config) do
    instance = mci_field(mci, :instance)
    check = mci_field(mci, :check)

    should_include_check(analyzer_config.check_configs, check) and
      should_include_instance(analyzer_config.instances, instance)
  end

  @spec should_include_check([CheckConfig.t()], binary()) :: boolean()
  def should_include_check([], _check), do: true

  def should_include_check(check_configs, check) do
    check_configs
    |> Enum.any?(&(&1.check_logical_name == check))
  end

  @spec should_include_instance([binary()], binary()) :: boolean()
  def should_include_instance([], _instance), do: true

  def should_include_instance(instances, instance) do
    instances
    |> Enum.any?(&(&1 == instance))
  end

  @spec remove_stale_check_details(Snapshot.t()) :: Snapshot.t()
  def remove_stale_check_details(snapshot = %Snapshot{}) do
    check_details =
      Enum.filter(snapshot.check_details, fn %{last_checked: last_checked} ->
        Timex.diff(NaiveDateTime.utc_now(), last_checked, :hours) < @max_check_details_age_hours
      end)

    %Snapshot{snapshot | check_details: check_details}
  end

  @spec set_correlation_id(Snapshot.t()) :: Snapshot.t()
  def set_correlation_id(new_snapshot),
    do: %Snapshot{new_snapshot | correlation_id: Ecto.UUID.generate()}

  @spec set_correlation_id(Snapshot.t(), Snapshot.t()) :: Snapshot.t()
  def set_correlation_id(new_snapshot, nil), do: set_correlation_id(new_snapshot)

  def set_correlation_id(new_snapshot, %Snapshot{correlation_id: nil}),
    do: set_correlation_id(new_snapshot)

  def set_correlation_id(new_snapshot, %Snapshot{correlation_id: ""}),
    do: set_correlation_id(new_snapshot)

  def set_correlation_id(new_snapshot, %Snapshot{state: :up}) when new_snapshot.state != :up,
    do: set_correlation_id(new_snapshot)

  def set_correlation_id(new_snapshot, existing_snapshot),
    do: %Snapshot{new_snapshot | correlation_id: existing_snapshot.correlation_id}

  @spec get_check_config_for_mci(%AnalyzerConfig{}, mci()) :: CheckConfig.t()
  def get_check_config_for_mci(analyzer_config, {_, _, check, _}) do
    case Enum.find(analyzer_config.check_configs, &(&1.check_logical_name == check)) do
      nil -> CheckConfig.get_defaults(analyzer_config, check)
      cfg -> CheckConfig.fill_empty_with_defaults(cfg, analyzer_config)
    end
  end

  @spec mci_field(mci(), :account | :check | :instance | :monitor) :: binary()
  def mci_field({account, _, _, _}, :account), do: account
  def mci_field({_, monitor, _, _}, :monitor), do: monitor
  def mci_field({_, _, check, _}, :check), do: check
  def mci_field({_, _, _, instance}, :instance), do: instance

  @spec get_check_config_for_mci(Snapshot.t(), [binary()]) :: Snapshot.t()
  def order_check_details(snapshot, run_steps) do
    ordered_check_details =
      snapshot.check_details
      |> Enum.reduce([], fn cd, new_list ->
        case Enum.find_index(run_steps, fn check -> cd.check_id == check end) do
          nil ->
            new_list

          index ->
            List.insert_at(
              new_list,
              index,
              cd
            )
        end
      end)

    remaining_check_details =
      snapshot.check_details
      |> Enum.reject(fn cd -> Enum.any?(run_steps, fn check_id -> check_id == cd.check_id end) end)
      |> Enum.sort_by(fn cd -> cd.check_id end)

    new_check_details = ordered_check_details ++ remaining_check_details

    %Snapshot{snapshot | check_details: new_check_details}
  end

  @spec update_status_page_component_check_details(
          Snapshot.t(),
          Domain.StatusPage.Events.ComponentStatusChanged.t()
        ) ::
          Snapshot.t()
  def update_status_page_component_check_details(snapshot, event) do
    if Enum.any?(
         snapshot.status_page_component_check_details,
         &(&1.check_id == event.component_id)
       ) do
      check_details =
        for cd <- snapshot.status_page_component_check_details do
          if cd.check_id == event.component_id do
            %CheckDetail{
              cd
              | state: String.to_atom(event.state),
                last_checked: event.changed_at,
                created_at: event.changed_at
            }
            |> status_page_component_check_detail_message()
          else
            cd
          end
        end

      %{
        snapshot
        | status_page_component_check_details: check_details,
          last_updated: NaiveDateTime.utc_now()
      }
    else
      snapshot
    end
  end

  @spec remove_status_page_component_check_detail(Snapshot.t(), binary()) :: Snapshot.t()
  def remove_status_page_component_check_detail(snapshot, check_id) do
    if Enum.any?(snapshot.status_page_component_check_details, &(&1.check_id == check_id)) do
      check_details =
        Enum.reject(snapshot.status_page_component_check_details, fn cd ->
          cd.check_id == check_id
        end)

      %{
        snapshot
        | status_page_component_check_details: check_details,
          last_updated: NaiveDateTime.utc_now()
      }
    else
      snapshot
    end
  end

  @spec set_status_page_component_check_details(Snapshot.t(), [
          {binary(), ComponentChange.t()}
        ]) ::
          Snapshot.t()
  def set_status_page_component_check_details(snapshot, component_changes) do
    check_details =
      for {status_page_component_id, change} <- component_changes do
        %CheckDetail{
          check_id: status_page_component_id,
          instance: change.instance,
          name: change.component_name,
          state: change.state,
          created_at: change.changed_at,
          # This is being used by SlackBody.alert_message
          last_checked: change.changed_at
        }
        |> status_page_component_check_detail_message()
      end

    %{snapshot | status_page_component_check_details: check_details}
  end

  @spec add_status_page_component_check_details(Snapshot.t(), binary(), ComponentChange.t()) ::
          Snapshot.t()
  def add_status_page_component_check_details(snapshot, component_id, change) do
    check_details = [
      %CheckDetail{
        check_id: component_id,
        instance: change.instance,
        name: change.component_name,
        state: change.state,
        created_at: change.changed_at,
        last_checked: change.changed_at
      }
      |> status_page_component_check_detail_message()
      | snapshot.status_page_component_check_details
    ]

    %{snapshot | status_page_component_check_details: check_details}
  end

  def notification_header_state(snapshot) do
    if snapshot.state == :up and
         Enum.any?(snapshot.status_page_component_check_details, &(&1.state != :up)) do
      :degraded
    else
      snapshot.state
    end
  end

  def has_default_last_checked?(%Snapshot{last_checked: @min_date_time}), do: true
  def has_default_last_checked?(_), do: false

  defp status_page_component_check_detail_message(check_detail) do
    # TODO: Append message scraped from the status page component
    %{check_detail | message: "#{check_detail.name}"}
  end

  defp get_blocked_steps(mci, errors = [_ | _]) do
    {_account, _monitor, _check, instance} = mci
    {_, error} = List.last(errors)
    Enum.map(error[:blocked_steps] || [], fn step -> {instance, step} end)
  end

  defp get_blocked_steps(_mci, _errors), do: []

  defp pass_outstanding_corr_id(new_snapshot, corr_id) when is_nil(corr_id), do: new_snapshot

  defp pass_outstanding_corr_id(new_snapshot, corr_id),
    do: %Snapshot{new_snapshot | correlation_id: corr_id}

  defp get_check_name(check_id, monitor) do
    Monitor.get_checks(monitor)
    |> Enum.find(fn %MonitorCheck{logical_name: logical_name} -> logical_name == check_id end)
    |> case do
      %MonitorCheck{name: name} -> name
      _ -> check_id
    end
  end
end
