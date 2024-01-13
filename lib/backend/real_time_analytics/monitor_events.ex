defmodule Backend.RealTimeAnalytics.MonitorEvents do
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail
  alias Backend.RealTimeAnalytics.SnapshottingHelpers
  require Logger

  @typep monitor_event_id :: binary()
  @typep check_id :: binary()
  @typep instance_name :: binary()
  @typep correlation_id :: String.t()
  @type monitor_event :: {monitor_event_id(), check_id(), instance_name(), correlation_id(), Backend.RealTimeAnalytics.Snapshotting.state()}
  @type check_details :: list(CheckDetail.t())
  @type opts :: [
          account_id: binary(),
          monitor_id: binary(),
          correlation_id: binary(),
          new_snapshot_state: atom()
        ]
  @type t :: list(monitor_event())

  @doc """
  Checks for state transition occured between `current_check_details` and `new_check_details`
  and returns a tuple of `{outstanding_monitor_events, commanded_commands}`
  """
  @spec process_events(check_details(), check_details(), t(), opts()) ::
          {t(), list(term())}
  def process_events(current_check_details, new_check_details, outstanding_events, opts \\ []) do
    transitioned_checks =
      for {_check, %{previous: previous, current: current}} <-
            SnapshottingHelpers.combine_check_details(
              current_check_details,
              new_check_details
            ),
          SnapshottingHelpers.did_state_transition?(previous, current, outstanding_events),
          do: current

    do_process_events(transitioned_checks, outstanding_events, opts)
  end

  defp do_process_events([], outstanding_events = [], _), do: {outstanding_events, []}

  # No transitioned checks, but still have outstanding events. Check if snapshot is up and if so,
  # end all of the outstanding events and set them as up. This shouldn't be a common occurance.
  defp do_process_events([], outstanding_events, opts) do
    new_snapshot_state = Keyword.get(opts, :new_snapshot_state)
    if new_snapshot_state == :up do
      account_id = Keyword.get(opts, :account_id)
      monitor_id = Keyword.get(opts, :monitor_id)
      #correlation_id = Keyword.get(opts, :correlation_id)

      end_time = NaiveDateTime.utc_now()

      aggregate_id = Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor_id)

      cmds = Enum.flat_map(outstanding_events, fn {event_id, check_id, instance_name, correlation_id, _state} ->
        [
          %Domain.Monitor.Commands.EndEvent{
            id: aggregate_id,
            monitor_event_id: event_id,
            end_time: end_time
          },
          %Domain.Monitor.Commands.AddEvent{
            id: aggregate_id,
            event_id: Domain.Id.new(),
            instance_name: instance_name,
            check_logical_name: check_id,
            state: "up",
            message: "#{check_id} is responding normally from #{instance_name}",
            start_time: end_time,
            end_time: end_time,
            correlation_id: correlation_id
          }
        ]
      end)

      {[], cmds}
    else
      {outstanding_events, []}
    end
  end

  defp do_process_events(transitioned_checks, outstanding_events, opts) do
    account_id = Keyword.get(opts, :account_id)
    monitor_id = Keyword.get(opts, :monitor_id)
    correlation_id = Keyword.get(opts, :correlation_id)
    command_id = Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor_id)

    transitioned_check_id = Enum.into(transitioned_checks, MapSet.new(), & &1.check_id)

    Logger.info("RTA Monitor Events has #{length(transitioned_checks)} transitioned checks")

    {events_ended, outstanding_events} =
      Enum.split_with(
        outstanding_events,
        fn {_event_id, check_id, _instance_name, _corr_id, _state} -> MapSet.member?(transitioned_check_id, check_id) end
      )

    end_event_cmds =
      for {event_id, _check_id, _instance_name, _corr_id, _state} <- events_ended do
        %Domain.Monitor.Commands.EndEvent{
          id: command_id,
          monitor_event_id: event_id,
          end_time: NaiveDateTime.utc_now()
        }
      end

    add_event_cmds =
      for check <- transitioned_checks do
        end_time = if check.state == :up, do: check.last_checked, else: nil

        %Domain.Monitor.Commands.AddEvent{
          id: command_id,
          event_id: Domain.Id.new(),
          check_logical_name: check.check_id,
          instance_name: check.instance,
          message: check.message,
          start_time: check.last_checked,
          correlation_id: correlation_id,
          state: to_string(check.state),
          end_time: end_time
        }
      end

    additional_outstanding_events = add_event_cmds
    |> Enum.reject(fn cmd -> cmd.state == "up" end)
    |> Enum.map(fn cmd -> {cmd.event_id, cmd.check_logical_name, cmd.instance_name, cmd.correlation_id, String.to_atom(cmd.state)} end)

    {additional_outstanding_events ++ outstanding_events, end_event_cmds ++ add_event_cmds}
  end
end
