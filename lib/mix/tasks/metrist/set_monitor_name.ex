defmodule Mix.Tasks.Metrist.SetMonitorName do
  use Mix.Task


  alias Mix.Tasks.Metrist.Helpers
  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    {:name, nil, :string, :mandatory, "Human readable name to give to the monitor"}
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

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Monitor.Commands.ChangeName{
        id: options.monitor_id,
        name: options.name
      },
      options.env, options.dry_run)
  end
end
