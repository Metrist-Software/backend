defmodule Mix.Tasks.Metrist.OneOff.HubspotCreateAndSyncMetristProperties do
  use Mix.Task
  alias Backend.Integrations.Hubspot
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @opts [
    :env,
  ]
  @shortdoc "Creates and initially seeds new Hubspot Metrist properties"


  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)
    Backend.Application.configure_hubspot()
    Logger.configure(level: :info)
    Application.ensure_all_started(:hackney)

    if Enum.all?(create_properties(), &(&1 == true)) do
      sync_data()
    end
  end

  defp create_properties() do
    group_name = "metrist_account_details"


    params = %{
      name: group_name,
      label: "Metrist account details",
      displayOrder: -1
    }

    created_property_group = case Hubspot.get_property_group_details(group_name) do
      {:ok, _} ->
        Logger.info("#{params.name} already exists")
        true
      {:error, _} ->
        case Hubspot.create_property_groups(params, "contact") do
          {:ok, _} ->
            Logger.info("Successfully created #{params.name}")
            true
          {:error, reason} ->
            Logger.error("Failed to create property group #{params.name}. #{reason}")
            false
        end
    end

    case created_property_group do
      false -> [false]
      true ->
        [
          %{
            name: "metrist_user_acquisition",
            label: "Metrist user acquisition",
            type: "enumeration",
            fieldType: "select",
            groupName: group_name,
            options: [
              %{
                label: "Creator",
                value: "Creator",
                displayOrder: 0,
                hidden: false
              },
              %{
                label: "Invited",
                value: "Invited",
                displayOrder: 1,
                hidden: false
              }
            ]
          },
          %{
            name: "metrist_account_created_by",
            label: "Hubspot account created by",
            type: "enumeration",
            fieldType: "select",
            groupName: group_name,
            options: [
              %{
                label: "Metrist Web App",
                value: "Metrist Web App",
                displayOrder: 0,
                hidden: false
              }
            ]
          },
          %{
            name: "metrist_account_name",
            label: "Metrist account name",
            type: "string",
            fieldType: "text",
            groupName: group_name
          },
          %{
            name: "metrist_account_id",
            label: "Metrist account ID",
            type: "string",
            fieldType: "text",
            groupName: group_name
          },
          # ugh no datetime field but it's been on the roadmap for more than 3 years... https://community.hubspot.com/t5/HubSpot-Ideas/Allow-creation-of-datetime-field-from-Contact-Property-area-not/idi-p/249242
          %{
            name: "metrist_last_login",
            label: "Metrist last login",
            type: "string",
            fieldType: "text",
            groupName: group_name
          }
        ]
        |> Enum.map(fn property_params ->
          case Hubspot.get_property_details(property_params.name) do
            {:ok, _} ->
              Logger.info("#{property_params.name} already exists")
              true
            {:error, _} ->
              case Hubspot.create_property(property_params, "contact") do
                {:ok, _} ->
                  Logger.info("Successfully created #{property_params.name}")
                  true
                {:error, reason} ->
                  Logger.error("Failed to create property #{property_params.name}. #{reason}")
                  false
              end
          end
        end)
      end
  end

  defp sync_data() do
    accounts = Map.new(Enum.map(Backend.Projections.list_accounts(),  &{&1.id, &1}))

    hubspot_updates = for user <- Enum.filter(Backend.Projections.list_users(), &(&1.hubspot_contact_id)) do
      properties = %{
            metrist_last_login: get_last_login(user.last_login),
            metrist_account_created_by: "Metrist Web App",
            metrist_account_id: "",
            metrist_account_name: "",
            metrist_user_acquisition: ""
      }

      Logger.info("Processing user id #{user.id} and account id #{user.account_id}")
      properties = case user.account_id do
        nil -> properties
        _ ->
          %{
            metrist_account_id: user.account_id,
            metrist_account_name: get_account_name(accounts, user.account_id),
            metrist_user_acquisition: get_user_aquisition(user)
          }
          |> Enum.into(properties)
      end

      %{
        id: user.hubspot_contact_id,
        properties: properties
      }
    end

    Logger.info("Making #{length(hubspot_updates)} updates to hubspot")

    hubspot_updates
    |> Enum.chunk_every(10)
    |> Enum.each(fn list ->
      Hubspot.batch_update_contacts(list)
    end)
  end

  defp get_last_login(nil), do: ""
  defp get_last_login(last_login), do: "#{NaiveDateTime.to_string(last_login)} UTC"

  defp get_account_name(accounts, account_id) do
    case Map.get(accounts, account_id) do
      nil ->
        Logger.warn("Account id #{account_id} doesn't exist in accounts table.")
        ""
      account -> Backend.Projections.Account.get_account_name(account)
    end
  end

  defp get_user_aquisition(user) do
    try do
      case length(Backend.Projections.get_invites_for_user(user.id, user.account_id)) do
        0 -> "Creator"
        _ -> "Invited"
      end
    rescue
      error ->
        Logger.warn("Error trying to query invites for #{user.account_id}. Error: #{inspect error}")
        ""
    end
  end
end
