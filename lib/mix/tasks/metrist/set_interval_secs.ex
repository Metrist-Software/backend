defmodule Mix.Tasks.Metrist.SetIntervalSecs do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Sets the interval for a monitor config"

  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    :config_id,
    {:interval_secs, nil, :integer, :mandatory, "Seconds to wait between monitor runs"}
  ]

  @moduledoc """
  Sets value for a monitor_config's `interval_secs` field

  #{Helpers.gen_command_line_docs(@opts)}

  ## Examples:

      mix metrist.set_interval_secs -e dev1 -m testsignal -c 11vpT2grcoxX5qg9ckLCqlP -a SHARED --interval-secs 600
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Helpers.send_command(
      %Domain.Monitor.Commands.SetIntervalSecs{
        id: options.monitor_id,
        config_id: options.config_id,
        interval_secs: options.interval_secs
      },
      options.env, options.dry_run
    )
  end
end
