defmodule Mix.Tasks.Metrist.OneOff.FixAzureSqlConfig do
  use Mix.Task

  @shortdoc "MET-466 Remove SECRETS_NAMESPACE from Azure SQL. Change run group."

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

    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Task.run("app.config")
    # Mix.Tasks.Metrist.Helpers.start_repos()

    [:ex_aws_secretsmanager, :hackney, :jason]
    |> Enum.map(&Application.ensure_all_started/1)

    select = fn dev_id, prod_id ->
      case opts[:env] do
        "dev1" -> dev_id
        "prod" -> prod_id
      end
    end

    azure_regions =
      case opts[:env] do
        "dev1" -> ["az:eastus"]
        "prod" -> ["az:eastus", "az:eastus2", "az:centralus", "az:southcentralus", "az:westus", "az:westus2", "az:canadacentral"]
      end

    cmds = []

    # Azure AKS
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuresql")
    config_id = select.("11wcVlmpEe9K23MRlscoMWw", "11wcqlbMpuNsAQGiQ33zeQ2")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "ClientID",
            value: "@env@:@secret@:/${ENVIRONMENT_TAG}/azure/api-token#client-id"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "TenantID",
            value: "@env@:@secret@:/${ENVIRONMENT_TAG}/azure/api-token#tenant-id"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "ClientSecret",
            value: "@env@:@secret@:/${ENVIRONMENT_TAG}/azure/api-token#client-secret"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "SubscriptionID",
            value: "@env@:@secret@:/${ENVIRONMENT_TAG}/azure/api-token#subscription-id"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: azure_regions
          }
        ]

    Mix.Tasks.Metrist.Helpers.send_commands(cmds, opts[:env])
  end
end
