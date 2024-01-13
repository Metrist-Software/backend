defmodule Mix.Tasks.Metrist.OneOff.FixAzureDevopsConfigs do
  use Mix.Task

  @shortdoc "MET-429 Remove SECRETS_NAMESPACE from Azure DevOps monitor configs"

  def run(args) do
    {opts, []} =
      OptionParser.parse!(
        args,
        strict: [env: :string],
        aliases: [e: :env]
      )

    missing =
      [:env]
      |> Enum.filter(fn opt -> is_nil(opts[opt]) end)

    if length(missing) > 0, do: raise("Missing required option(s): #{inspect(missing)}")
    IO.inspect(opts, label: "Parsed options")

    select = fn dev_id, prod_id ->
      case opts[:env] do
        "dev1" -> dev_id
        "prod" -> prod_id
      end
    end

    azure_region =
      case opts[:env] do
        "dev1" -> "az:eastus"
        "prod" -> "az:centralus" # Hopefully this matches Azure DevOps "US Central"
      end

    cmds = []

    # Azure DevOps Boards
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuredevopsboards")
    config_id = select.("11wn71VNKVLwHIQkTTfJRpr", "11wnXhgUHdLjHrgzorom2yg")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Organization",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#ORGANIZATION"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "PersonalAccessToken",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#AZDO_PERSONAL_ACCESS_TOKEN"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Project",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#REPOSITORY"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Team",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#TEAM_ID"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: [azure_region]
          }
        ]

    # Azure DevOps Pipelines
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuredevopspipelines")
    config_id = select.("11wset99rOEGA6gZ1yXCA4A", "11wsjrQ8uxYM1KmI3SfhCAq")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Organization",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#ORGANIZATION"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "PersonalAccessToken",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#AZDO_PERSONAL_ACCESS_TOKEN"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Project",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#REPOSITORY"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: [azure_region]
          }
        ]

    # Azure DevOps Test Plans
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuredevopstestplans")
    config_id = select.("11woVzaauW2e7S1yjx40ncv", "11wqhlNB09g6JWY943xN8TH")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Organization",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#ORGANIZATION"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "PersonalAccessToken",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#AZDO_PERSONAL_ACCESS_TOKEN"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Project",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#REPOSITORY"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "Team",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#TEAM_ID"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: [azure_region]
          }
        ]

    # Azure DevOps Artifacts
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuredevopsartifacts")
    config_id = select.("11wt5WxtVaqBCWO7UPhrWhw", "11wttLrF9v6WCzYRwNjlcAO")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: [azure_region]
          }
        ]

    # Azure DevOps Repositories
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuredevops")
    config_id = select.("11wjGEizwIuGFH4Vl2UOlE5", "11wlYHsS4ecE43Y7za2iItK")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "organization",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#ORGANIZATION"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "personalAccessToken",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#AZDO_PERSONAL_ACCESS_TOKEN"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "repository",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/azuredevops/access-token#REPOSITORY"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: [azure_region]
          }
        ]
    Mix.Tasks.Metrist.Helpers.send_commands(cmds, opts[:env])
  end
end
