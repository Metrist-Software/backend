defmodule Mix.Tasks.Metrist.OneOff.FixAzureConfigs do
  use Mix.Task

  @shortdoc "MET-428 Remove SECRETS_NAMESPACE from Azure monitors and add platform for the ones that require it. Copy region specific secrets to us-east-1/us-west-2 as appropriate for Azure VM"

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

    azure_cdn_regions =
      case opts[:env] do
        "dev1" -> ["az:eastus"]
        "prod" -> ["az:eastus", "az:eastus2", "az:centralus", "az:southcentralus", "az:westus", "az:canadacentral"]
      end

    azure_vm_regions =
      case opts[:env] do
        "dev1" -> ["az:eastus"]
        "prod" -> ["az:eastus", "az:eastus2", "az:westus", "az:westus2", "az:canadacentral"]
      end

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

    for {env, aws_region, azure_region, new_aws_region, new_env} <- Map.get(env_map, opts[:env]) do
      {:ok, %{"SecretString" => secret_string}} =
        "/#{env}/azurevm/credentials"
        |> ExAws.SecretsManager.get_secret_value()
        |> ExAws.request(region: aws_region)

        # Write azure orchestrator entries
        ExAws.SecretsManager.create_secret(
          name: "/#{new_env}/az/#{azure_region}/azurevm/credentials",
          client_request_token: UUID.uuid1(),
          secret_string: secret_string)
        |> ExAws.request(region: new_aws_region)
        |> IO.inspect()

        # Write aws orchestrator entries (in case we spin up here again) in each aws region
        ExAws.SecretsManager.create_secret(
          name: "/#{env}/aws/#{aws_region}/azurevm/credentials",
          client_request_token: UUID.uuid1(),
          secret_string: secret_string)
        |> ExAws.request(region: aws_region)
        |> IO.inspect()
    end

    cmds = []

    # Azure AKS
    id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azureaks")
    config_id = select.("11vxrmSjnnf6bmjNFTC4wI", "11vyAYHSYuC4AZBcYBldJ5v")
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

        # Azure Blob
        id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azureblob")
        config_id = select.("11vpT2hn6ObE3rmpRawt2fM", "11vscoh4XKfiAZadUQmwHxG")
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

        # Azure DB
        id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azuredb")
        config_id = select.("11vwt5hM8Xp1Lel8JHbCXuU", "11vxLrbwK9ciKa5DyTpfFf4")
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

        # Azure VM
        id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azurevm")
        config_id = select.("11vpT2hkIqlfLwKUlMlyFXI", "11vscohvB4SJHBtTD8XPWvz")
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
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "PersistentInstanceName",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurevm/credentials#instance-name"
              },
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "PersistentInstanceResourceGroup",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurevm/credentials#instance-resource-group"
              },
              %Domain.Monitor.Commands.SetRunGroups{
                id: id,
                config_id: config_id,
                run_groups: azure_vm_regions
              }
            ]

        # Azure CDN
        id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azurecdn")
        config_id = select.("11wjETlHo9VLDudZ29uhleH", "11wkOjfMN8lA46WMdeFWQZD")
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
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "CacheFileName",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurecdn/credentials#cache-file-name"
              },
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "CdnProfileName",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurecdn/credentials#cdn-profile-name"
              },
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "CdnEndpointName",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurecdn/credentials#cdn-endpoint-name"
              },
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "ResourceGroupName",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurecdn/credentials#resource-group-name"
              },
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "BlobStorageContainerName",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurecdn/credentials#blob-storage-container-name"
              },
              %Domain.Monitor.Commands.SetExtraConfig{
                id: id,
                config_id: config_id,
                key: "BlobStorageConnectionString",
                value: "@secret@:@env@:/${ENVIRONMENT_TAG}/${CLOUD_PLATFORM}/${EXECUTION_REGION}/azurecdn/credentials#blob-storage-connection-string"
              },
              %Domain.Monitor.Commands.SetRunGroups{
                id: id,
                config_id: config_id,
                run_groups: azure_cdn_regions
              }
            ]


        # Azure AppService
        id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", "azureappservice")
        config_id = select.("11wtryakDnoR70J09N7cgHJ", "11wuEwcWLHNRKXKLsX55Bxp")
        cmds =
          cmds ++
            [
              %Domain.Monitor.Commands.SetRunGroups{
                id: id,
                config_id: config_id,
                run_groups: azure_cdn_regions
              }
            ]

    Mix.Tasks.Metrist.Helpers.send_commands(cmds, opts[:env])
  end
end
