defmodule Mix.Tasks.Metrist.SetVisibleMonitors do
  @moduledoc """
  Sets visible_monitors

    mix metrist.set_visible_monitors --account="account_id,account_id2" awslambda ec2 s3
    # Set for all account
    mix metrist.set_visible_monitors --account="all" awslambda ec2 s3
  """
  use Mix.Task
  require Logger

  def run(args) do
    {opts, additional_visible_monitors} =
      OptionParser.parse!(args, switches: [account: :string, env: :string])

    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Tasks.Metrist.Helpers.start_repos(opts[:env])

    account_ids = get_account_ids(opts[:account])

    commands =
      for account_id <- account_ids,
          visible_monitors =
            Backend.Projections.Dbpa.VisibleMonitor.visible_monitor_logical_names(account_id),
          visible_monitors_set = MapSet.new(visible_monitors),
          additional_visible_monitors_set =
            MapSet.new(additional_visible_monitors)
            |> MapSet.difference(visible_monitors_set),
          # if additional_visible_monitors_set is empty, don't bother sending a command
          additional_visible_monitors_set != MapSet.new() do
        %Domain.Account.Commands.SetVisibleMonitors{
          id: account_id,
          monitor_logical_names:
            MapSet.union(visible_monitors_set, additional_visible_monitors_set)
            |> Enum.to_list()
            |> Enum.sort()
        }
        |> IO.inspect(
          label: "Command for account: #{account_id}",
          printable_limit: :infinity,
          limit: :infinity
        )
      end

    if commands != [] do
      if Mix.shell().yes?("There are #{length(commands)} to be applied for #{opts[:env]}? Do you wish to apply all the commands") do
        Mix.Tasks.Metrist.Helpers.send_commands(commands, opts[:env])
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
