defmodule Mix.Tasks.Metrist.SetMonitorTag do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    {:tag, nil, :string, :mandatory, "The tag to set"}
  ]
  @shortdoc "Sets the tag for a monitor"
  @moduledoc """
  Sets a monitor's tag

  #{Helpers.gen_command_line_docs(@opts)}

  ## Examples:

      mix metrist.set_monitor_tag -e dev1 -m asana -a SHARED --tag "saas"

  """
  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Monitor.Commands.AddTag{
        id: options.monitor_id,
        tag: options.tag
      },
      options.env, options.dry_run)
  end
end
