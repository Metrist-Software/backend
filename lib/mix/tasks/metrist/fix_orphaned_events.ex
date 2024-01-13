defmodule Mix.Tasks.Metrist.FixOrphanedEvents do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @opts [
    :dry_run,
    :env
  ]

  @shortdoc "Search for events that should have ended but havent and end them."

  @moduledoc """
  This mix task will search for events more than a week old without an end and generate an end
  for them as they were likely orphaned.

  NOTE: This task does not look at errors/telemetry to determine that the week long event isn't valid.

    MIX_ENV=prod mix metrist.fix_orphaned_events --env dev1

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    Logger.configure(level: :info)

    opts = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)
    Application.ensure_all_started(:timex)

    cmds = Backend.Projections.list_accounts()
    |> Enum.map(fn account ->
      Logger.info("Checking account with id: #{account.id}")
      for mon <- Backend.Projections.list_monitors(account.id) do
        Backend.Projections.Dbpa.MonitorEvent.outstanding_events(account.id, mon.logical_name)
        |> Enum.map(& maybe_end_event(&1, account, mon))
        |> List.flatten()
      end
      |> List.flatten()
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil(&1))
    |> IO.inspect(limit: :infinity, pretty: true)

    Logger.info("============ Need to send #{length(cmds)} commands to fix up current orphans ==========")

    Helpers.send_commands(
      cmds,
      opts.env, opts.dry_run)
  end

  defp maybe_end_event(event, account, mon) do
    if NaiveDateTime.compare(event.start_time, Timex.shift(NaiveDateTime.utc_now(), weeks: -1) ) == :lt do
      end_time = Timex.shift(event.start_time, seconds: 1)
      cmds = [
        %Domain.Monitor.Commands.EndEvent{
        id: Backend.Projections.construct_monitor_root_aggregate_id(account.id, mon.logical_name),
        monitor_event_id: event.id,
        end_time: end_time
        },
        %Domain.Monitor.Commands.AddEvent{
          id: Backend.Projections.construct_monitor_root_aggregate_id(account.id, mon.logical_name),
          event_id: Domain.Id.new(),
          instance_name: event.instance_name,
          check_logical_name: event.check_logical_name,
          state: "up",
          message: "#{event.check_logical_name} is reponding normally from #{event.instance_name}",
          start_time: end_time,
          end_time: end_time,
          correlation_id: event.correlation_id
        }
      ]

      # monitor_state_timeline uses monitor_events from shared and generated alerts from other accounts
      # if this is from an account other than SHARED we have to generate the alert to truly fix this up
      case account.id do
        "SHARED" ->
          Logger.debug("Event with id #{event.id} is for SHARED, so not generating an alert entry")
          cmds
        _ ->
          [%Domain.Account.Commands.AddAlerts{
            id: account.id,
            alerts: [
              %Domain.Account.Commands.Alert {
                alert_id: Domain.Id.new(),
                correlation_id: event.correlation_id,
                monitor_logical_name: mon.logical_name,
                state: "up",
                is_instance_specific: false,
                subscription_id: nil,
                formatted_messages: %{backend_code: "#{event.check_logical_name}:#{event.instance_name} - Metrist generated"},
                affected_regions: [],
                affected_checks: [],
                # Push out another few minute to account for delay from event to alert generation
                generated_at: Timex.shift(end_time, minutes: 3)
              }
            ]
          } | cmds]
      end
    else
      nil
    end
  end
end
