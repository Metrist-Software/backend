defmodule Mix.Tasks.Metrist.EndEvent do
  use Mix.Task


  alias Mix.Tasks.Metrist.Helpers
  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    {:monitor_event_id, nil, :string, :mandatory, "The event ID that we want to end"},
    {:end_time, nil, :integer, :mandatory, "When to end the event as an integer in Unix time (seconds)"}
  ]
  @shortdoc "Sets the name for a monitor"
  @moduledoc """
  Sets a monitor's name field

  #{Helpers.gen_command_line_docs(@opts)}

  ## Examples:

      mix metrist.set_monitor_name -e dev1 -m testsignal -a SHARED --name "Test Signal"

  """
  def run(args) do
    options = Helpers.parse_args(@opts, args)

    dt = %{DateTime.to_naive(DateTime.from_unix!(options.end_time)) | microsecond: {0, 6}}

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Monitor.Commands.EndEvent{
        id: options.monitor_id,
        monitor_event_id: options.monitor_event_id,
        end_time: dt
      },
      options.env, options.dry_run)
  end
end
