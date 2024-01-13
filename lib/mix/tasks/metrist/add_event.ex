defmodule Mix.Tasks.Metrist.AddEvent do
  use Mix.Task


  alias Mix.Tasks.Metrist.Helpers
  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    {:start_time, nil, :integer, :mandatory, "When to start the event as an integer in Unix time (seconds)"},
    {:end_time, nil, :integer, :mandatory, "When to end the event as an integer in Unix time (seconds)"},
    {:message, nil, :string, :mandatory, "Message for the event"},
    {:check_logical_name, nil, :string, :mandatory, "Check logical name to apply the event to"},
    {:instance_name, nil, :string, :mandatory, "Instance name for the event"},
    {:state, nil, :string, :mandatory, "state for the event up degraded down"},
    {:correlation_id, nil, :string, :mandatory, "Correlation ID for the event"}
  ]
  @shortdoc "Adds an event to the system"
  @moduledoc """
  Sets a monitor's name field

  #{Helpers.gen_command_line_docs(@opts)}

  ## Examples:

      mix metrist.set_monitor_name -e dev1 -m testsignal -a SHARED --name "Test Signal"

  """
  def run(args) do
    options = Helpers.parse_args(@opts, args)

    start_time = %{DateTime.to_naive(DateTime.from_unix!(options.start_time)) | microsecond: {0, 6}}
    end_time = %{DateTime.to_naive(DateTime.from_unix!(options.end_time)) | microsecond: {0, 6}}

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Monitor.Commands.AddEvent{
        id: options.monitor_id,
        event_id: Domain.Id.new(),
        instance_name: options.instance_name,
        check_logical_name: options.check_logical_name,
        state: options.state,
        message: options.message,
        start_time: start_time,
        end_time: end_time,
        correlation_id: options.correlation_id
      },
      options.env, options.dry_run)
  end
end
