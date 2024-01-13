defmodule Mix.Tasks.Metrist.OneOff.FixCustomerConfigsAfterPlatformMigration do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-231, MET-232, MET-233 script to update elements of customer configs after some monitors were exclusive moved to other platforms/regions."

  def run(args) do
    {opts, []} = Helpers.do_parse_args(
      args,
      [
        env: :string,
        dry_run: :boolean
      ],
      [
        e: :env,
        d: :dry_run
      ],
      [
        :env
      ]
    )


    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Task.run("app.config")
    # Mix.Tasks.Metrist.Helpers.start_repos()
    Logger.configure(level: :info)

    azure_instances =
      case opts[:env] do
        "local" -> ["az:eastus"]
        "dev1" -> ["az:eastus"]
        "prod" ->
          [
            "az:eastus",
            "az:eastus2",
            "az:centralus",
            "az:southcentralus",
            "az:westus",
            "az:westus2",
            "az:canadacentral"
          ]
      end

    gcp_instances =
      case opts[:env] do
        "local" -> ["gcp:us-west1"]
        "dev1" -> ["gcp:us-west1"]
        "prod" ->
          [
            "gcp:northamerica-northeast1",
            "gcp:northamerica-northeast2",
            "gcp:us-central1",
            "gcp:us-east1",
            "gcp:us-east4",
            "gcp:us-west1",
            "gcp:us-west2",
            "gcp:us-west3",
            "gcp:us-west4"
          ]
      end

    affected_azure_monitors =
      [
        "azurefncs",
        "azuremonitor",
        "azuredevopsartifacts",
        "azuredevops",
        "azurevm",
        "azuredb",
        "azureappservice",
        "azuread",
        "azuredevopsboards",
        "azureaks",
        "azureblob",
        "azuredevopstestplans",
        "azuresql",
        "azuredevopspipelines",
        "azurecdn"
      ]

    affected_gcp_monitors =
      [
        "gke",
        "gcpcloudstorage",
        "gcpcomputeengine",
      ]

    do_check_config = fn (account, cfg, affected_monitors, prefix, instances) ->
      if cfg.instances == [] do
        []
      else
        case Enum.member?(affected_monitors, cfg.monitor_logical_name) do
          true ->
            case Enum.any?(cfg.instances, &(String.starts_with?(&1, prefix))) do
              false ->
                Logger.debug("Adding #{prefix} instances for #{account.id}:#{cfg.monitor_logical_name}")
                [%Domain.Monitor.Commands.UpdateAnalyzerConfig{
                  id: Backend.Projections.construct_monitor_root_aggregate_id(account.id, cfg.monitor_logical_name),
                  default_degraded_threshold: cfg.default_degraded_threshold,
                  default_degraded_down_count: cfg.default_degraded_down_count,
                  default_degraded_up_count: cfg.default_degraded_up_count,
                  default_error_down_count: cfg.default_error_down_count,
                  default_error_up_count: cfg.default_error_up_count,
                  default_degraded_timeout: cfg.default_degraded_timeout,
                  default_error_timeout: cfg.default_error_timeout,
                  instances: cfg.instances ++ instances,
                  check_configs: cfg.check_configs
                }]
              _ ->
                Logger.debug("Not adding #{prefix} instances for #{account.id}:#{cfg.monitor_logical_name} as they already have explicit instances")
                []
            end
          _ -> []
        end
      end
    end

    check_azure_config = fn account, cfg ->
      do_check_config.(account, cfg, affected_azure_monitors, "az:", azure_instances)
    end

    check_gcp_config = fn account, cfg ->
      do_check_config.(account, cfg, affected_gcp_monitors, "gcp:", gcp_instances)
    end

    get_commands_for_config = fn account, cfg ->
      cmds = check_azure_config.(account, cfg)
      cmds = cmds ++ check_gcp_config.(account, cfg)
      cmds
      |> List.flatten()
    end

    Logger.info("Preparing commands... Please wait...")
    all_commands =
      for account <- Backend.Projections.list_accounts() do
        # ensure all accounts have azure/gcp instances in their defaults incase they add an azure/gcp monitor
        # (until the new ui is ready for them to do this themselves)
        # new accounts have the option to choose azure/gcp instances
        # The new signup flow will force an "at least once" selection for each cloud in use by a selected monitor when done
        # if they already have one of either don't add anything for that platform
        # existing [] doesn't get touched
        cmds = []

        existing_instances =
          Backend.Projections.get_instances(account.id)
          |> Enum.map(&(&1.name))

        cmds = cmds ++
                if existing_instances == [] do
                  Logger.debug("No default instances found for account #{account.id}. Not adding azure/gcp as they already have everything")
                  []
                else
                  azure_instances_to_add = case Enum.any?(existing_instances, fn instance -> String.starts_with?(instance, "az:") end) do
                    true -> []
                    _ -> azure_instances
                  end

                  gcp_instances_to_add = case Enum.any?(existing_instances, fn instance -> String.starts_with?(instance, "gcp:") end) do
                    true -> []
                    _ -> gcp_instances
                  end

                  [
                    %Domain.Account.Commands.SetInstances{
                      id: account.id,
                      instances: Enum.uniq(existing_instances ++ azure_instances_to_add ++ gcp_instances_to_add)
                    }
                  ]
                end

        # check all analyzer configs for an azure or gcp monitor with no azure/gcp instances
        # (since most accounts didn't have azure/gcp instances in their default_instances previously and they could have added one or more)
        # if they already have an azure or gcp instance for that respective monitor, don't change anything otherwise add them all
        # Existing [] doens't get touched
        cmds =
          cmds ++
            (
              Backend.Projections.get_analyzer_configs(account.id)
              |> Enum.map(fn cfg -> get_commands_for_config.(account, cfg) end)
              |> List.flatten()
            )

        # add all azure/gcp monitors as visible monitors for all accounts as some older accounts don't have them and can't add them
        # Follow up ticket exist to create an admin UI to allow metrist staff to do this in bulk easily)
        # Existing [] doesn't get touched
        existing_visible_monitors = Backend.Projections.Dbpa.VisibleMonitor.visible_monitor_logical_names(account.id)
        cmds =
          if existing_visible_monitors == [] do
            Logger.debug("Not changing visible monitors for #{account.id} as they already have everything")
            cmds
          else
            cmds ++ [
              %Domain.Account.Commands.SetVisibleMonitors{
                id: account.id,
                monitor_logical_names: Enum.uniq(existing_visible_monitors ++ affected_azure_monitors ++ affected_gcp_monitors)
              }
            ]
        end

        cmds
      end
      |> List.flatten()

    case opts[:dry_run] do
      true ->
        all_commands
        |> IO.inspect(label: "Commands")
        Logger.info("#{length(all_commands)} commands would be sent")
      _ ->
        Logger.info("Sending #{length(all_commands)} commands")
        Mix.Tasks.Metrist.Helpers.send_commands(all_commands, opts[:env])
        Logger.info("Done sending #{length(all_commands)} commands")
    end
  end
end
