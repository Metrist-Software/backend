defmodule Mix.Tasks.Metrist.OneOff.OptinMissingHubspotEmailPreferences do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  import Ecto.Query, only: [from: 2]
  require Logger

  @opts [
    :env,
    {:since, :nil, :string, :mandatory, "Lower bound date of which the user is created"},
  ]

  @shortdoc "Sync Metrist Monitoring users with Hubspot Contacts"

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    options.env
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Backend.Application.configure_hubspot()
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    account_ids = hubspot_account_ids(NaiveDateTime.from_iso8601!(options.since))

    if Mix.shell().yes?("Found #{length(account_ids)} accounts. Do you wish to continue?") do
      Enum.map(account_ids,
        &%{
          id: &1,
          properties: %{receive_company_news: true, receive_product_updates_email: true, receive_weekly_report: true}
        }
      )
      |> Enum.chunk_every(10)
      |> Enum.flat_map(&Backend.Integrations.Hubspot.batch_update_contacts!/1)
    end

  end


  def hubspot_account_ids(start_time) do
    query = from u in Backend.Projections.User,
      where: u.inserted_at > ^start_time,
      where: not is_nil(u.hubspot_contact_id),
      select: u.hubspot_contact_id

    Backend.Repo.all(query)
  end
end
