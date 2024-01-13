defmodule Mix.Tasks.Metrist.OneOff.MigrateTimeoutsToMs do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @shortdoc "Migrate Analyzer Config degraded and error timeouts to ms from s"
  # No moduledoc, one-off commands don't need to appear in `mix help`
  # Will migrate anything with a sub 1000 value (likely a second value less than the 900 max to value * 1000)

  def run(args) do
    {parsed, []} =
      Helpers.do_parse_args(
        args,
        [
          env: :string
        ],
        [e: :env],
        [:env]
      )

    config = Helpers.config_from_env(parsed[:env])
    Helpers.config_to_env(config)
    Mix.Task.run("app.config")
    # Mix.Tasks.Metrist.Helpers.start_repos()

    #%{"token" => token} =
      Backend.Application.get_json_secret(
        "canary-internal/api-token",
        config.secrets_namespace,
        config.region
      )

    for account <- Backend.Projections.list_accounts() do
      for analyzer_config <- Backend.Projections.get_analyzer_configs(account.id) do
        transformed_check_configs = transform_check_configs(analyzer_config.check_configs)
        # if something changed in the check configs, persist it. If not there's no need
        if transformed_check_configs != analyzer_config.check_configs do
          account_id = account.id
          monitor_logical_name = analyzer_config.monitor_logical_name

          Logger.info("Updating check config timeout values for #{account_id}:#{monitor_logical_name}")
          %Domain.Monitor.Commands.UpdateAnalyzerConfig{
            id: Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor_logical_name),
            default_degraded_threshold: analyzer_config.default_degraded_threshold,
            default_degraded_down_count: analyzer_config.default_degraded_down_count,
            default_degraded_up_count: analyzer_config.default_degraded_up_count,
            default_error_down_count: analyzer_config.default_error_down_count,
            default_error_up_count: analyzer_config.default_error_up_count,
            default_degraded_timeout: analyzer_config.default_degraded_timeout,
            default_error_timeout: analyzer_config.default_error_timeout,
            instances: analyzer_config.instances,
            check_configs: transform_check_configs(analyzer_config.check_configs)
          }

          #Mix.Tasks.Metrist.Helpers.send_command(config, token, cmd)
        end
      end
    end
  end

  defp transform_check_configs(check_configs) when is_nil(check_configs), do: nil
  defp transform_check_configs(check_configs) do
    check_configs
    |> Enum.map(fn config ->
        transform_individual_config(config)
      end)
  end

  defp transform_individual_config(config) do
    config
    |> translate_timeout_value("DegradedTimeout")
    |> translate_timeout_value("ErrorTimeout")
  end

  defp translate_timeout_value(config, timeout_name) when is_map_key(config, timeout_name) do
    existing_timeout = config
    |> Map.get(timeout_name, 900000)

    new_value = case existing_timeout do
      nil -> nil
      _ ->
        case existing_timeout > 1000 do
          true -> existing_timeout
          false -> existing_timeout * 1000
        end
    end

    config
    |> Map.put(timeout_name, new_value)
  end

  defp translate_timeout_value(config, _timeout_name), do: config
end
