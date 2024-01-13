defmodule Mix.Tasks.Metrist.EmptyVisibleMonitors do
  @moduledoc """
  Empties visible_monitors

    mix metrist.empty_visible_monitors --account="account_id,account_id2"
    # Set for all account
    mix metrist.set_visible_monitors --account="all"
  """
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger


  @opts [
    :dry_run,
    :env,
    {:accounts, nil, :string, :mandatory, "Accounts affected"}

  ]

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)


    account_ids = get_account_ids(options.accounts)

    commands =
        Enum.map(account_ids, fn acc-> %Domain.Account.Commands.SetVisibleMonitors{
          id: acc,
          monitor_logical_names:
            []
        }
      end)

    if commands != [] do
      if Mix.shell().yes?("There are #{length(commands)} to be applied for #{options.env}? Do you wish to apply all the commands") do
        Mix.Tasks.Metrist.Helpers.send_commands(commands, options.env)
      end
    else
      IO.puts("No commands to be executed")
    end
  end

  defp get_account_ids("all") do
    for account <- Backend.Projections.list_accounts() do
      account.id
    end
  end

  defp get_account_ids(accounts), do: String.split(accounts, ",")
end
