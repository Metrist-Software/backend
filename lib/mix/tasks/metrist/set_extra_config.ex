defmodule Mix.Tasks.Metrist.SetExtraConfig do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    :config_id,
    {:config, nil, :keep, :mandatory, "Configuration `key=value` pair"}
  ]
  @shortdoc "Set values on a monitor's extra_config"
  @moduledoc """
  Sets values for a monitor_config's extra_config object. Requires a monitor_config to already exist.
  If one does not, it can be created with the Mix.Tasks.Metrist.CreateMonitor mix task

  Multiple config flags can be passed to set multiple values at once. Config values should be of the
  form key=value

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}

  ## Example:

      mix metrist.set_extra_config -c 234o90768wefolijh --config key1=value1 --config key2=value2 -e local --monitor-logical-name=my-monitor

      MIX_ENV=prod mix metrist.set_extra_config -c 234o90768wefolijh --config key1=value1 --config key2=value2 -e dev --monitor-logical-name=my-monitor
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    commands =
      options.config
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.map(fn [key, val] ->
        %Domain.Monitor.Commands.SetExtraConfig{
          id: options.monitor_id,
          config_id: options.config_id,
          key: key,
          value: val
        }
      end)

    Helpers.send_commands(commands, options.env, options.dry_run)

    Logger.info("All done!")
  end
end
