defmodule Mix.Tasks.Metrist.RemoveMonitorConfig do
  use Mix.Task

  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Removes a monitor config by id."

  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    :config_id
  ]

  @moduledoc """
  #{@shortdoc}

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Helpers.send_command(
      %Domain.Monitor.Commands.RemoveConfig{
        id: options.monitor_id,
        config_id: options.config_id
      },
      options.env, options.dry_run
    )
  end
end
