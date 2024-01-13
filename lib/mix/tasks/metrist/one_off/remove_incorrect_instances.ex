defmodule Mix.Tasks.Metrist.OneOff.RemoveIncorrectInstances do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-985 script to remove incorrect instances from azure monitors"

  @opts [
    :dry_run,
    :env
  ]

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Task.run("app.config")
    Mix.Tasks.Metrist.Helpers.start_repos(opts[:env])
    Logger.configure(level: :info)

    target_cleanup_tags = ["azure"]

    monitor_tags =
      Backend.Projections.Dbpa.MonitorTags.list_monitors_by_tag()
      |> Enum.into(%{}, fn {tag, monitor, _name} -> {monitor, tag} end)

    all_commands =
      Backend.Projections.list_accounts()
      |> Enum.flat_map(fn account ->
        build_account_commands(account.id, monitor_tags, target_cleanup_tags)
      end)

    case opts[:dry_run] do
      true ->
        IO.inspect(all_commands, label: "Commands")

        Logger.info("#{length(all_commands)} commands would be sent")

      _ ->
        Logger.info("Sending #{length(all_commands)} commands")
        if Mix.shell().yes?("Do you wish to proceed") do
          Mix.Tasks.Metrist.Helpers.send_commands(all_commands, opts[:env])
          Logger.info("Done sending #{length(all_commands)} commands")  
        end
        
    end
  end

  defp build_account_commands(account_id, monitor_tags, target_cleanup_tags) do
    Backend.Projections.get_analyzer_configs(account_id)
    |> Enum.reject(fn cfg ->
      # If the monitor config is from a status page only monitor, skip it
      cfg.instances == []
    end)
    |> Enum.filter(fn cfg ->
      instances_needs_cleanup?(cfg, monitor_tags, target_cleanup_tags)
    end)
    |> Enum.map(fn cfg ->
      %Domain.Monitor.Commands.UpdateAnalyzerConfig{
        id:
          Backend.Projections.construct_monitor_root_aggregate_id(
            account_id,
            cfg.monitor_logical_name
          ),
        default_degraded_threshold: cfg.default_degraded_threshold,
        default_degraded_down_count: cfg.default_degraded_down_count,
        default_degraded_up_count: cfg.default_degraded_up_count,
        default_error_down_count: cfg.default_error_down_count,
        default_error_up_count: cfg.default_error_up_count,
        default_degraded_timeout: cfg.default_degraded_timeout,
        default_error_timeout: cfg.default_error_timeout,
        instances:
          Enum.filter(cfg.instances, fn instance ->
            instance_of?(monitor_tags[cfg.monitor_logical_name], instance)
          end),
        check_configs: cfg.check_configs
      }
    end)
  end

  defp instances_needs_cleanup?(analyzer_config, monitor_tags, target_cleanup_tags) do
    tag = monitor_tags[analyzer_config.monitor_logical_name]

    tag in target_cleanup_tags and
      # Returns true if any of the instances does not belong to the correct tag
      # For example: 
      # instances = ["gcp:region1", "aws:mon1", "gcp:region2"], tag: "gcp", returns true
      Enum.any?(analyzer_config.instances, fn instance -> not instance_of?(tag, instance) end)
  end

  defp instance_of?("gcp", instance),
    do: String.starts_with?(instance, "gcp:")

  defp instance_of?("azure", instance),
    do: String.starts_with?(instance, "az:")

  defp instance_of?(_tag, _instance), do: true
end
