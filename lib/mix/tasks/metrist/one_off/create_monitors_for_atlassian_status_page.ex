defmodule Mix.Tasks.Metrist.OneOff.CreateMonitorsForAtlassianStatusPage do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Sets up monitors with fake telemtry from a list of monitor logical names"

  @opts [
    :dry_run,
    :env,
    :account_id
  ]

  @tags %{
    saas: [
      {"Opsgenie", "opsgenie"},
      {"LaunchPad", "launchpad"},
      {"Lightspeed", "lightspeed"},
      {"Humi", "humi"},
      {"FreshBooks", "freshbooks"},
      {"Nobl9", "nobl9"},
      {"Lightstep", "lightstep"},
      {"Gitpod", "gitpod"},
      {"LogRocket", "logrocket"},
      {"Eclipse Foundation Services", "eclipsefoundationservices"},
      {"Maven Central", "mavencentral"},
      {"Discord", "discord"},
      {"Strava", "strava"},
      {"Linode", "linode"},
      {"Netlify", "netlify"},
      {"RubyGems.org", "rubygemsorg"},
      {"Authorize.net", "authorizenet"},
      {"Hotjar", "hotjar"},
      {"TaxJar", "taxjar"},
      {"Atlassian Bitbucket", "atlassianbitbucket"}
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
