defmodule Mix.Tasks.Metrist.OneOff.HubspotSyncContacts do
  use Mix.Task
  alias Backend.Integrations.Hubspot
  alias Backend.Repo
  alias Backend.Projections.User
  alias Domain.User.Commands.CreateHubspotContact
  import Ecto.Query

  @shortdoc "Sync Metrist Monitoring users with Hubspot Contacts"

  @moduledoc """
  Sync Metrist Monitoring users with Hubspot Contacts

      mix metrist.hubspot_sync_ontacts

  This task will take all the hubspot contacts & compares it to our hubspot_contact projection to see if a metrist user has a hubspot contact.
  Creates hubspot contact for a metrist user if none is found

  Options
    * --env   (required) The target environment e.g. `local`, `dev`, `prod`. Non-local require's running with `MIX_ENV=prod`
    * --subscribe_company_news    Subscribes all contacts with unset `Company News` property
  """

  @default_query %{"limit" => 100, "properties" => "email,receive_company_news"}

  def run(args) do
    {opts, []} =
      Mix.Tasks.Metrist.Helpers.do_parse_args(
        args,
        [
          env: :string,
          subscribe_company_news: :boolean
          ],
        [],
        [:env]
      )

    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Task.run("app.config")
    Backend.Application.configure_hubspot()
    # Mix.Tasks.Metrist.Helpers.start_repos()
    #Mix.Tasks.Metrist.Helpers.start_commanded()
    Application.ensure_all_started(:hackney)

    if opts[:subscribe_company_news] do
      subscribe_company_news()
    else
      sync_contacts()
    end
  end

  def subscribe_company_news do
    # Only setting receive_company_news to match landing page form
    success_count = get_all_contacts()
    |> Enum.filter(& &1["properties"]["receive_company_news"] == nil)
    |> Enum.map(&%{
      id: &1["id"],
      properties: %{
        receive_company_news: true
      }})
    |> Enum.chunk_every(10)
    |> Enum.flat_map(&Hubspot.batch_update_contacts!/1)
    |> Enum.count()

    IO.puts("Successfully updated #{success_count} contacts")
  end

  def sync_contacts do
    # Get all existing hubspot contacts
    existing_hubspot_accounts = get_all_contacts() |> results_to_email_contact_id_map()
    hubspot_emails = Map.keys(existing_hubspot_accounts)

    # Get all metrist users that has hubspot contact but is missing in hubspot_contact table
    query =
      from u in User,
        as: :user,
        where: fragment("lower(?)", u.email) in ^hubspot_emails and is_nil(u.hubspot_contact_id)

    Repo.all(query)
    |> Enum.map(
      &%CreateHubspotContact{
        id: &1.id,
        contact_id: Map.fetch!(existing_hubspot_accounts, String.downcase(&1.email))
      }
    )
    |> Enum.map(&dispatch/1)

    # Get all metrist users DO NOT have a hubspot contact & create them on hubspot. Dispatch commands to populate the hubspot_contact table as well
    query =
      from u in User,
        as: :user,
        where: fragment("lower(?)", u.email) not in ^hubspot_emails

    user_without_hubspot_account_by_email =
      Repo.all(query)
      |> Enum.into(%{}, &{String.downcase(&1.email), &1})

    # Create new hubspot contacts
    results =
      Map.keys(user_without_hubspot_account_by_email)
      |> Enum.map(&%{properties: %{email: &1}})
      # Hubspot only allows 10 contacts per each batch create call
      |> Enum.chunk_every(10)
      |> Enum.flat_map(&Hubspot.batch_create_contacts!/1)

    new_hubspot_accounts = results_to_email_contact_id_map(results)

    Map.values(user_without_hubspot_account_by_email)
    |> Enum.map(
      &%CreateHubspotContact{
        id: &1.id,
        contact_id: Map.fetch!(new_hubspot_accounts, &1.email)
      }
    )
    |> Enum.map(&dispatch/1)
  end

  def get_all_contacts do
    resp = list_contacts!()
    Process.sleep(1000)

    get_all_contacts(resp, resp["results"])
  end

  defp get_all_contacts(%{"paging" => %{"next" => %{"after" => after_page}}}, accumulator) do
    resp = list_contacts!(%{"after" => after_page})
    Process.sleep(1000)
    get_all_contacts(resp, resp["results"] ++ accumulator)
  end

  defp get_all_contacts(_, accumulator), do: accumulator

  defp list_contacts!(query \\ %{}) do
    case Map.merge(@default_query, query) |> Hubspot.list_contacts() do
      {:ok, resp} -> resp
      {:error, reason} -> raise "Error: #{reason}"
    end
  end

  defp results_to_email_contact_id_map(results) do
    results
    |> Enum.map(&{&1["properties"]["email"], &1["id"]})
    |> Enum.into(%{})
  end

  def dispatch(cmd), do: Backend.App.dispatch_with_actor(Backend.Auth.Actor.metrist_mix(), cmd)
end
