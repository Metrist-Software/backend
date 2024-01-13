defmodule Mix.Tasks.Metrist.OneOff.MonitorUse do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc "Determine which accounts are using a monitor and/or have subscriptions"
  @moduledoc """
  Determine which accounts are using a monitor and/or have subscriptions

  Options:
    - --env / -e: Environment to run in. Either "local" to run locally or
    deployed instances `ENVIRONMENT_TAG` value. Non-local require's running with
    `MIX_ENV=prod`
    - --monitor / -m: Monitor ID to check.

  Examples:

      MIX_ENV=prod mix metrist.monitor_use -m twiliovid -e prod

      mix metrist.monitor_use -m twiliovid -e local
  """
  def run(args) do
    Logger.configure(level: :info)

    {opts, []} = Helpers.do_parse_args(
    args, [
      env: :string,
      monitor: :string
    ],[
      e: :env,
      m: :monitor
    ],[
      :env,
      :monitor
    ])

    config = Helpers.config_from_env(opts[:env])
    Helpers.config_to_env(config)

    Mix.Task.run("app.config")
    # Mix.Tasks.Metrist.Helpers.start_repos()

    monitor_logical_name = opts[:monitor]

    IO.puts("Checking for accounts with monitor...")
    accounts = Backend.Projections.get_accounts_for_monitor(monitor_logical_name)
    IO.puts("Checking for active subscriptions to monitor...")
    accounts_with_subscriptions = Backend.Projections.get_accounts_with_subscription_to_monitor(monitor_logical_name)

    IO.puts("\nReport for monitor: #{monitor_logical_name}")
    IO.puts("\n# of accounts with monitor #{length(accounts)}")
    for account <- accounts do
      IO.puts("#{account.id} - #{account.name}")
    end
    IO.puts("\n# of accounts with subscriptions #{length(accounts_with_subscriptions)}")
    for account <- accounts_with_subscriptions do
      IO.puts("#{account.id} - #{account.name}")
    end
  end
end
