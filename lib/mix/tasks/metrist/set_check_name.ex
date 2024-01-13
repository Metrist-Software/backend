defmodule Mix.Tasks.Metrist.SetCheckName do
  use Mix.Task


  alias Mix.Tasks.Metrist.Helpers
  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    {:name, nil, :string, :mandatory, "Human readable name to give to the check"},
    {:check_logical_name, nil, :string, :mandatory, "Check logical name to change"}
  ]
  @shortdoc "Sets the name for a check"
  @moduledoc """
  Sets a check's name field

  #{Helpers.gen_command_line_docs(@opts)}

  ## Examples:

      mix metrist.set_check_name -e dev1 -m awsroute53 -a SHARED --check_logical_name "QueryExistingDNSRecord" --name "Query existing DNS record"

  """
  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Monitor.Commands.UpdateCheckName{
        id: options.monitor_id,
        logical_name: options.check_logical_name,
        name: options.name
      },
      options.env, options.dry_run)
  end
end
