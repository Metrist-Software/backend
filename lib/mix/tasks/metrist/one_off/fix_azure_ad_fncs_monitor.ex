defmodule Mix.Tasks.Metrist.OneOff.FixAzureAdFncsMonitor do
  use Mix.Task

  @shortdoc "MET-430 Remove SECRETS_NAMESPACE from Azure FNCS and Azure Monitor and add platform for the ones that require it. Copy region specific secrets to us-east-1/us-west-2 as appropriate for Azure FNCS and Azure Monitor"

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

    # only setting current regions for now as there is infra for both monitor and azurefncs that would need to be setup and they don't have TF for it.
    # follow up ticket will be created. For now we'll run it on the ones that we know are setup properly (existing regions)
    existing_azure_regions =
      case opts[:env] do
        "dev1" -> ["az:eastus"]
        "prod" -> ["az:eastus", "az:eastus2", "az:westus", "az:westus2", "az:canadacentral"]
      end

    all_azure_regions =
      case opts[:env] do
        "dev1" -> ["az:eastus"]
        "prod" -> ["az:eastus", "az:eastus2", "az:centralus", "az:southcentralus", "az:westus", "az:westus2", "az:canadacentral"]
      end

    # {env, aws_region, azure_region, new_aws_region, new_env}
    env_map =
      %{
        "dev1" => [{"dev1", "us-east-1", "eastus", "us-east-1", "dev1"}],
        "prod" =>
        [
          {"prod", "us-west-2", "westus2", "us-west-2", "prod"},
          {"prod2", "us-east-2", "eastus2", "us-west-2", "prod"},
          {"prod-mon-us-east-1", "us-east-1", "eastus", "us-west-2", "prod"},
          {"prod-mon-us-west-1", "us-west-1", "westus", "us-west-2", "prod"},
          {"prod-mon-ca-central-1", "ca-central-1", "canadacentral", "us-west-2", "prod"}
        ]
    }

    for env_mapping <- Map.get(env_map, opts[:env]) do
      "azurefncs/credentials"
      |> copy_secret(env_mapping)

      "azuremonitor/credentials"
      |> copy_secret(env_mapping)
    end

    cmds = []

    # Azure Functions
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azurefncs")
    config_id = select.("11wenkcZgUOQ9aKFb7TAK0d", "11wevJ7nfUgtewdhfqhS4s")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "TestFunctionUrl",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurefncs/credentials#TestFunctionUrl"
          },
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "TestFunctionCode",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurefncs/credentials#TestFunctionCode"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: existing_azure_regions
          }
        ]

    # Azure Monitor
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuremonitor")
    config_id = select.("11wrVG11HPgT83IeCRCiB0W", "11wsgvKWk1LGEL87f1AkQFN")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetExtraConfig{
            id: id,
            config_id: config_id,
            key: "ConnectionString",
            value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azuremonitor/credentials#ConnectionString"
          },
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: existing_azure_regions
          }
        ]

    # Azure AD
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuread")
    config_id = select.("11vpT2ibcKMPD5VY60Ekyj", "11vscojPDirZEognyqpHKQa")
    cmds =
      cmds ++
        [
          %Domain.Monitor.Commands.SetRunGroups{
            id: id,
            config_id: config_id,
            run_groups: all_azure_regions
          }
        ]

    Mix.Tasks.Metrist.Helpers.send_commands(cmds, opts[:env])
  end

  defp copy_secret(secret_to_copy, {env, aws_region, azure_region, new_aws_region, new_env}) do
    {:ok, %{"SecretString" => secret_string}} =
      "/#{env}/#{secret_to_copy}"
      |> ExAws.SecretsManager.get_secret_value()
      |> ExAws.request(region: aws_region)

      # Write azure orchestrator entries
      ExAws.SecretsManager.create_secret(
        name: "/#{new_env}/az/#{azure_region}/#{secret_to_copy}",
        client_request_token: UUID.uuid1(),
        secret_string: secret_string)
      |> ExAws.request(region: new_aws_region)
      |> IO.inspect()

      # Write aws orchestrator entries (in case we spin up here again) in each aws region
      ExAws.SecretsManager.create_secret(
        name: "/#{env}/aws/#{aws_region}/#{secret_to_copy}",
        client_request_token: UUID.uuid1(),
        secret_string: secret_string)
      |> ExAws.request(region: aws_region)
      |> IO.inspect()
  end
end
