defmodule Mix.Tasks.Metrist.OneOff.HubspotSyncTrialData do
  use Mix.Task
  alias Backend.Integrations.Hubspot
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @opts [
    :env,
  ]
  @shortdoc "Syncs existing trial data to HubSpot"

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)
    Backend.Application.configure_hubspot()
    Logger.configure(level: :info)
    Application.ensure_all_started(:hackney)

    Backend.Projections.list_accounts(preloads: [:original_user, :memberships])
    |> Enum.map(&get_account_properties/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.chunk_every(10)
    |> Enum.each(&Hubspot.batch_update_contacts/1)
  end

  defp get_account_properties(account = %{original_user: nil}) do
    Logger.warn("Account #{account.id} has no original user. Skipping")
    nil
  end

  defp get_account_properties(account = %{original_user: %{hubspot_contact_id: nil}}) do
    Logger.warn("Original user of account #{account.id} has no hubspot contact id. Skipping")
    nil
  end

  defp get_account_properties(account = %{original_user: %{hubspot_contact_id: hubspot_contact_id}}) do
    membership_tier = case Enum.find(account.memberships, & is_nil(&1.end_date)) do
      nil -> "trial"
      %{tier: tier} -> Atom.to_string(tier)
    end

    %{
      id: hubspot_contact_id,
      properties: %{
        "metrist_membership_tier" => membership_tier,
        "metrist_trial_end_date" => Hubspot.format_date_property!(account.free_trial_end_time)
      }
    }
  end
end
