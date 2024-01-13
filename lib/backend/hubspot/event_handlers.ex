# Possible optimization: Use a new typed_handler macro to
# subscribe to just what we need
# See Backend.Projectors.TypeStreamLinker.Helpers
defmodule Backend.Hubspot.EventHandlers do
  use Backend.Projectors.TypeStreamLinker.Helpers
  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  require Logger
  alias Backend.Integrations.Hubspot

  @impl true
  def handle(e = %Domain.Account.Events.Created{}, %{"actor" => %{"kind" => "user", "id" => user_id}}) do
    set_account_creation_details(user_id, e, "Metrist Web App")
    :ok
  end

  def handle(e = %Domain.Account.Events.Created{}, %{"actor" => %{"kind" => "datadog", "user_id" => user_id}}) do
    Logger.info("Datadog account creation seen for user #{user_id}")
    set_account_creation_details(user_id, e, "Metrist Datadog App")
  end

  def handle(e = %Domain.Account.Events.NameUpdated{}, _metadata) do
    decrypted_event = Domain.CryptUtils.decrypt(e)
    Backend.Projections.list_users_for_account(e.id)
    |> Enum.reject(&(is_nil(&1.hubspot_contact_id)))
    |> Enum.map(fn user ->
      %{
        id: user.hubspot_contact_id,
        properties: %{
          metrist_account_name: decrypted_event.name,
        }
      }
    end)
    |> Hubspot.batch_update_contacts()
    :ok
  end

  def handle(e = %Domain.Account.Events.FreeTrialUpdated{}, _metadata) do
    case Backend.Projections.get_account(e.id, [:original_user]) do
      %{original_user: %{hubspot_contact_id: hubspot_contact_id}} ->
        Hubspot.update_contact(hubspot_contact_id, %{
          metrist_trial_end_date: Hubspot.format_date_property!(e.free_trial_end_time)
        })
      _ ->
        nil
    end
    :ok
  end

  def handle(%Domain.Account.Events.MembershipCreated{tier: tier}, %{"actor" => %{"kind" => "user", "id" => user_id}}),
    do: update_hubspot_membership_tier(tier, user_id)

  defp set_account_creation_details(user_id, e, created_by) do
    case Backend.Projections.get_user(user_id) do
      nil ->
        Logger.debug("User not found, not setting metrist_user_acquisition")
      user ->
        decrypted_event = Domain.CryptUtils.decrypt(e)

        Hubspot.update_contact(user.hubspot_contact_id, %{
          "metrist_account_created_by" => created_by,
          "metrist_user_acquisition" => "Creator",
          "metrist_account_id" => decrypted_event.id,
          "metrist_account_name" => decrypted_event.name,
          "metrist_membership_tier" => "trial",
          "metrist_trial_end_date" => Hubspot.format_date_property!(e.free_trial_end_time)
        })
    end
  end

  defp update_hubspot_membership_tier(tier, user_id) do
    case Backend.Projections.get_user(user_id) do
      nil ->
        Logger.debug("User not found, not setting metrist_membership_tier")
      user ->
        Hubspot.update_contact(user.hubspot_contact_id, %{
          "metrist_membership_tier" => tier
        })
    end
    :ok
  end
end
