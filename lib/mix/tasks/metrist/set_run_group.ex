defmodule Mix.Tasks.Metrist.SetRunGroup do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    :config_id,
    {:run_group, :r, :keep, :mandatory, "One or more run group names"}
  ]
  @shortdoc "Sets the rungroup for a monitor config"
  @moduledoc """
  Sets values for a monitor_config's `run_groups` field

  #{Helpers.gen_command_line_docs(@opts)}

  ## Examples:

      mix metrist.set_run_group -e dev1 -m testsignal -c 11vpT2grcoxX5qg9ckLCqlP -a SHARED --run-group "RunDLL" --run-group "SecondRunGroup"

      mix metrist.set_run_group -e dev1 -m testsignal -c 11vpT2grcoxX5qg9ckLCqlP -a SHARED --run-group "RunDLL"
  """
  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Monitor.Commands.SetRunGroups{
        id: options.monitor_id,
        config_id: options.config_id,
        run_groups: options.run_group},
      options.env, options.dry_run)
  end
end
