defmodule Mix.Tasks.Metrist.OneOff.RenamePlatformRegionExtraConfig do
  use Mix.Task
  alias Backend.Projections
  alias Backend.Projections.Dbpa.MonitorConfig
  alias Mix.Tasks.Metrist.Helpers

  @account_id "SHARED"

  @opts [
    :dry_run,
    :env
  ]

  @shortdoc "Renames unused environment variables from extra configs"

  @moduledoc """
  Renames unused environment variables from extra configs using the following logic

  1. For all monitor running on AWS, replace AWS_REGION to ORCHESTRATOR_REGION
  2. For all monitor NOT running on AWS, replace AZ_REGION and GCP_REGION to ORCHESTRATOR_REGION
  3. For all monitor NOT running on AWS replace AWS_REGION to AWS_BACKEND_REGION

  #{Helpers.gen_command_line_docs(@opts)}
  #{Helpers.mix_env_notice()}
  ## Example

    MIX_ENV=prod mix metrist.one_off.rename_platform_region_extra_config -e dev1 
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Helpers.start_repos(options.env)

    {aws_configs, non_aws_configs} =
      all_monitor_configs()
      |> Enum.split_with(fn %MonitorConfig{run_groups: run_groups} ->
        run_groups
        |> Enum.flat_map(fn rg -> String.split(rg, ":") end)
        |> Enum.member?("aws")
      end)

    aws_extra_config_commands_orchestrator_region =
      for config <- aws_configs,
          {key, value} <-
            filter_and_replace(config, ~r/AWS_REGION/, "ORCHESTRATOR_REGION"),
          do: build_command(config, key, value)

    non_aws_extra_config_commands_orchestrator_region =
      for config <- non_aws_configs,
          {key, value} <-
            filter_and_replace(config, ~r/(AZ_REGION|GCP_REGION)/, "ORCHESTRATOR_REGION"),
          do: build_command(config, key, value)

    non_aws_extra_config_commands_execution_region =
      for config <- non_aws_configs,
          {key, value} <-
            filter_and_replace(config, ~r/EXECUTION_REGION/, "ORCHESTRATOR_REGION"),
          do: build_command(config, key, value)

    non_aws_extra_config_commands_aws_backend_region =
      for config <- non_aws_configs,
          {key, value} <-
            filter_and_replace(config, ~r/AWS_REGION/, "AWS_BACKEND_REGION"),
          do: build_command(config, key, value)

    all_commands =
      aws_extra_config_commands_orchestrator_region ++
        non_aws_extra_config_commands_orchestrator_region ++
        non_aws_extra_config_commands_execution_region ++
        non_aws_extra_config_commands_aws_backend_region

    if options.dry_run do
      for command <- all_commands do
        IO.inspect(command)
      end
    else
      Helpers.send_commands(all_commands, options.env, options.dry_run)
    end

  end

  def all_monitor_configs do
    for %MonitorConfig{} = config <- Projections.get_monitor_configs(@account_id) do
      decrypted_config = Domain.CryptUtils.decrypt_field(config.extra_config)
      %{config | extra_config: decrypted_config}
    end
  end

  def filter_and_replace(%MonitorConfig{} = config, pattern, replacement)
      when config.extra_config != nil do
    Enum.flat_map(config.extra_config, fn {key, value} ->
      if String.match?(value, pattern) do
        [{key, String.replace(value, pattern, replacement)}]
      else
        []
      end
    end)
  end

  def filter_and_replace(_config, _pattern, _replacement), do: []

  def build_command(config, key, value) do
    monitor_id =
      Backend.Projections.construct_monitor_root_aggregate_id(
        @account_id,
        config.monitor_logical_name
      )

    %Domain.Monitor.Commands.SetExtraConfig{
      id: monitor_id,
      config_id: config.id,
      key: key,
      value: value
    }
  end
end
