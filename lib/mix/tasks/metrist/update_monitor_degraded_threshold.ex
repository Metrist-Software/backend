defmodule Mix.Tasks.Metrist.UpdateMonitorDegradedThreshold do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-1000 update AWS lambda degraded threshold"

  @opts [
    :dry_run,
    :env,
    {:monitor_name, nil, :string, :mandatory, "Name of monitor to update"},
    {:new_threshold, nil, :float, :mandatory, "New degraded threshold"}
  ]

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    monitor_logical_name = options.monitor_name

    account_ids = Backend.Projections.get_accounts_for_monitor(monitor_logical_name) |> Enum.map(fn a -> a.id end)

    shared_config = Backend.Projections.get_analyzer_config(Domain.Helpers.shared_account_id(), monitor_logical_name)

    cmds =  account_ids
    |> Enum.map(fn account ->
      analyzer_config = Backend.Projections.get_analyzer_config(account, monitor_logical_name)
      # Only update configs that are using the SHARED defaults
      # All the other defaults are nil when using SHARED, but default_degraded_threshold has it's actual value copied in
      if analyzer_config.default_degraded_threshold == shared_config.default_degraded_threshold do
        %Domain.Monitor.Commands.UpdateAnalyzerConfig{
          id: Backend.Projections.construct_monitor_root_aggregate_id(account, monitor_logical_name),
          default_degraded_threshold: options.new_threshold,
          default_degraded_down_count: analyzer_config.default_degraded_down_count,
          default_degraded_up_count: analyzer_config.default_degraded_up_count,
          default_error_down_count: analyzer_config.default_error_down_count,
          default_error_up_count: analyzer_config.default_error_up_count,
          default_degraded_timeout: analyzer_config.default_degraded_timeout,
          default_error_timeout: analyzer_config.default_error_timeout,
          instances: analyzer_config.instances,
          check_configs: analyzer_config.check_configs
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    Mix.Tasks.Metrist.Helpers.send_commands(cmds, options[:env], options[:dry_run])


  end
end
