defmodule Mix.Tasks.Metrist.OneOff.HubspotOptInAllBetaUsers do
  use Mix.Task
  alias Backend.Projections.User
  alias Backend.Repo
  alias Backend.Integrations.Hubspot
  import Ecto.Query

  @shortdoc "Make all beta users opt-in to all email subscriptions"

  @moduledoc """
  Make all beta users opt-in to all email subscriptions

      mix metrist.hubspot_opt_in_all_beta_users --env dev

  Options
    * --env   (required) The target environment e.g. `local`, `dev`, `prod`. Non-local require's running with `MIX_ENV=prod`
  """

  def run(args) do
    {opts, []} =
      Mix.Tasks.Metrist.Helpers.do_parse_args(
        args,
        [env: :string],
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

    check_all_users_have_hubspot_contact!()

    success_count = from(u in User, select: u.hubspot_contact_id)
    |> Repo.all()
    |> Enum.map(
      &%{
        id: &1,
        properties: %{receive_company_news: true, receive_product_updates_email: true, receive_weekly_report: true}
      }
    )
    |> Enum.chunk_every(10)
    |> Enum.flat_map(&Hubspot.batch_update_contacts!/1)
    |> Enum.count()

    IO.puts("Successfully updated #{success_count} contacts")
  end

  def check_all_users_have_hubspot_contact! do
    query = from(u in User, select: 1, where: is_nil(u.hubspot_contact_id))

    if Repo.exists?(query) do
      raise "Some users have nil hubspot_account_id. Please run mix metrist.hubspot_sync_contacts"
    end
  end
end
