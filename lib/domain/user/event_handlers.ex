defmodule Domain.User.EventHandlers do
  # NOTA BENE:
  #
  # This code does not belong here. It's a mix of event handlers like process managers
  # and projectors and introduces a dependency of the (theoretically pure) domain logic
  # to the (messy) backend app.
  #
  # If you need to touch this code, please consider moving it out. Also consider changing
  # things so they don't hook into the "$all" stream (adding a transaction on every
  # event write) but in specific type streams, e.g. wit the macros in TypeStreamLinker
  # (and probably some new ones there as well).
  #
  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  require Logger
  alias Backend.Integrations.Hubspot

  # NOTE: all commands emitted here must have idempotency checks in the
  # aggregate root!

  @impl true
  def handle(e = %Domain.User.Events.InviteCreated{}, _metadata) do
    account_name = case e.account_id do
      "SHARED" -> "Metrist"
      id -> case Backend.Projections.get_account(id) do
        nil -> nil
        %{name: nil} -> Backend.Projections.get_user(e.inviter_id) |> Map.get(:email)
        %{name: name} -> name
      end
    end

    handle_invite_created(e.id, e.invite_id, account_name)
  end

  @impl true
  def handle(
        e = %Domain.Account.Events.MonitorAdded{},
        %{
          "actor" => %{"kind" => "user", "id" => user_id},
          event_id: causation_id,
          correlation_id: correlation_id
        }
      ) do

    cmd = %Domain.User.Commands.SendMonitorSubscriptionReminder{
      id: user_id,
      monitor_logical_name: e.logical_name,
      monitor_name: e.name
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id,
      metadata: %{actor: Backend.Auth.Actor.backend_code()})

    :ok
  end

  @impl true
  def handle(e = %Domain.User.Events.SubscriptionReminderSent{ is_silent: false }, _) do
    case Backend.Projections.get_user(e.id) do
      nil ->
        Logger.warn("Could not find user associated with event #{inspect e}, not notifying")

      user ->
        # Not idempotent. So in the _unlikely_ case that we deploy while a user adds
        # a monitor for the first time, they logged in through slack, and they have their
        # slack workspace associated, they will get the slack DM twice

        # Don't want to wait for the MonitorAdded to project here so building a minimal one up
        Backend.Slack.SlackHelpers.SlackMessageHelpers.send_new_monitor_message(user, %Backend.Projections.Dbpa.Monitor{logical_name: e.monitor_logical_name, name: e.monitor_name})
    end

    :ok
  end

  @impl true
  def handle(e = %Domain.User.Events.InviteAccepted{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    user = Backend.Projections.get_user(e.id)
    account = Backend.Projections.get_account(e.account_id, [:original_user])

    case user do
      nil ->
        Logger.debug("User not found, not setting metrist_user_acquisition")
      user ->
        Hubspot.update_contact(user.hubspot_contact_id, %{
          "metrist_user_acquisition" => "Invited",
          "metrist_account_id" => e.account_id,
          "metrist_account_name" => Backend.Projections.Account.get_account_name(account)})

        cmd = %Domain.Account.Commands.AddUser{
          id: e.account_id,
          user_id: e.id,
        }
        Backend.App.dispatch(cmd,
          causation_id: causation_id,
          correlation_id: correlation_id,
          metadata: %{actor: Backend.Auth.Actor.backend_code()})
    end

    :ok
  end

  @impl true
  def handle(e = %Domain.User.Events.LoggedIn{}, _metadata) do
    user = Backend.Projections.get_user(e.id)
     case user do
      nil ->
        Logger.debug("User not found, not setting metrist_last_login")
      user ->
        Hubspot.update_contact(user.hubspot_contact_id, %{
          "metrist_last_login" => "#{NaiveDateTime.to_string(e.timestamp)} UTC",
        })
    end

    :ok
  end

  defp handle_invite_created(user_id, invite_id, account_name) do
    path = BackendWeb.Router.Helpers.live_path(BackendWeb.Endpoint, BackendWeb.LoginLive, invite_id)
    invite_link = BackendWeb.Endpoint.url <> path

    to_email = get_email_for_user_with_retries(user_id)

    # Not idempotent. So in the _unlikely_ case that we deploy while a user is
    # invited, someone will get an email twice.
    case Backend.SendEmail.send_invite_email(to_email, account_name, invite_link) do
      {:error, reason} -> Logger.error("Failed to send invite email due to #{inspect(reason)}. to_email: #{inspect(to_email)} account_name: #{inspect(account_name)} invite_link: #{inspect(invite_link)}")
      _ -> nil
    end

    :ok
  end

  # User projection is in a different stream so wait a bit
  @retries 5
  defp get_email_for_user_with_retries(user_id), do: get_email_for_user_with_retries(user_id, 0)
  defp get_email_for_user_with_retries(_, @retries), do: raise "Done waiting on email"
  defp get_email_for_user_with_retries(user_id, retries) do
    case Backend.Projections.get_user(user_id) do
      %{email: email} ->
        email
      _ ->
        Process.sleep(retries * 50)
        get_email_for_user_with_retries(user_id, retries + 1)
    end
  end
end
