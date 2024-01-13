defmodule Mix.Tasks.Metrist.SetRunSteps do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :env,
    :account_id,
    :monitor_logical_name,
    {:config_id, :c, :string, nil, "Monitor configuration id, if not specified first match will be taken from database"},
    {:default_timeout, nil, :float, Backend.Projections.Dbpa.MonitorConfig.default_timeout_secs(),
     "Default value, in seconds, for timeout when not specified in a step option"},
    {:steps, nil, :keep, [],
     "Monitor step. Can either be just the check name or a key-value pair `check=timeout`"}
  ]
  @shortdoc "Set steps for a monitor_config"
  @moduledoc """
  Sets values for a monitor_config's `steps` field

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}

  ## Examples:

      mix metrist.set_run_steps -e local -m testsignal --steps Zero --steps Normal=120 --steps Poisson --default-timeout 600

      MIX_ENV=prod mix metrist.set_run_steps -e dev1 -m testsignal --steps Zero=500 --steps Normal=600 --steps Poisson=600 -c 11vpT2grcoxX5qg9ckLCqlP

      MIX_ENV=prod mix metrist.set_run_steps -e prod -m testsignal --steps Zero --steps Normal --steps Poisson
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Helpers.start_repos(options.env)

    config_id = case options.config_id do
      nil -> Backend.Projections.get_monitor_config_by_name(options.account_id, options.monitor_logical_name).id
      _ -> options.config_id
    end

    steps =
      options.steps
      |> Enum.map(&(Helpers.parse_key_value_pair(&1, type: :float, default: options.default_timeout)))
      |> Enum.map(fn {step, timeout} -> %Domain.Monitor.Commands.Step{check_logical_name: step, timeout_secs: timeout} end)

    Helpers.send_command(
      %Domain.Monitor.Commands.SetSteps{
        id: options.monitor_id,
        config_id: config_id,
        steps: steps
      },
      options.env)
  end
end
