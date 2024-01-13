defmodule Mix.Tasks.Metrist.OneOff.CreateAdditionalMonitorsForGcpStatusPage do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Adds gcp status page only monitors to SHARED account"

  @opts [
    :dry_run,
    :env,
    :account_id
  ]

  @tags %{
    gcp: [
      {"Google Cloud SQL", "gcpcloudsql"},
      {"Cloud Load Balancing", "gcpcloudloadbalance"},
      {"Google BigQuery", "gcpgooglebigquery"},
      {"Secret Manager", "gcpsecretmanager"},
      {"Cloud Monitoring", "gcpcloudmonitoring"},
      {"Cloud Logging", "gcpcloudlogging"},
      {"Cloud Run", "gcpcloudrun"},
      {"Cloud Memorystore", "gcpcloudmemorystore"},
      {"Google Cloud Console", "gcpcloudconsole"},
      {"Google Cloud Networking", "gcpcloudnetworking"},
      {"Google Cloud Tasks", "gcpcloudtasks"},
      {"Identity and Access Management", "gcpidentityandaccessmanagement"},
      {"Virtual Private Cloud (VPC)", "gcpvirtualprivatecloud"}
    ]
  }

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    for {tag, monitors} <- @tags do
      IO.puts("tag: #{tag}")

      for {display_name, logical_name} <- monitors do
        monitor_id = Backend.Projections.construct_monitor_root_aggregate_id(options.account_id, logical_name)

        [
          %Domain.Account.Commands.AddMonitor{
            id: options.account_id,
            logical_name: logical_name,
            name: display_name,
            check_configs: [],
            default_degraded_threshold: 5.0,
            instances: [],
          },
          %Domain.Monitor.Commands.Create{
            id: monitor_id,
            monitor_logical_name: logical_name,
            name: display_name,
            account_id: options.account_id
          },
          %Domain.Monitor.Commands.AddTag{
            id: monitor_id,
            tag: tag
          }
        ]
      end
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Helpers.send_commands(options.env, options.dry_run, true)
    end
  end
end
