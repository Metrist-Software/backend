defmodule Domain.User do
  require Logger

  @derive Jason.Encoder
  defstruct [
    :id,
    :user_account_id,
    :email,
    :uid,
    :last_seen_slack_team_id,
    :last_seen_slack_user_id,
    :invites,
    :is_metrist_admin?,
    :is_read_only?,
    :last_subscription_reminder,
    :hubspot_contact_id,
    :timezone,
    monitor_subscription_reminders: []
  ]

  defmodule Invite do
    @derive Jason.Encoder
    defstruct [:id, :inviter_id, :account_id]
  end

  defmodule SubscriptionReminder do
    @derive Jason.Encoder
    defstruct [:monitor_logical_name, :sent_at]
  end

  alias Commanded.Aggregate.Multi
  alias __MODULE__.Commands
  alias __MODULE__.Events
  import Domain.Helpers

  # Command handling

  def execute(user = %__MODULE__{id: nil}, c = %Commands.Create{}) do
    create_user(user, c.id, c.user_account_id, c.email, c.uid, c.is_read_only)
  end
  def execute(user = %__MODULE__{id: nil}, c = %Commands.CreateInvite{}) do
    user
      |> Multi.new()
      |> Multi.execute(&create_user(&1, c.id, nil, c.email, nil, true))
      |> Multi.execute(&create_invite(&1, c.account_id, c.invite_id, c.inviter_id))
  end

  def execute(_user, %Commands.Create{}) do
    # Ignore duplicate registrations
    nil
  end
  def execute(%__MODULE__{id: nil}, c) do
    Logger.error("Invalid command on user that has not seen a Create: #{inspect c}")
    {:error, :no_create_command_seen}
  end


  def execute(user, c = %Commands.Update{}) do
    if user.user_account_id != c.user_account_id do
      user
      |> Multi.new()
      |> Multi.execute(&remove_invites_for_account_if_required(&1, c))
      |> Multi.execute(fn _ -> %Events.AccountIdUpdate{id: user.id, user_account_id: c.user_account_id} end)
    end
  end

  def execute(user, %Commands.Login{}) do
    %Events.LoggedIn{id: user.id,
                     timestamp: DateTime.utc_now()}
  end

  def execute(user, %Commands.DatadogLogin{}) do
    %Events.DatadogLoggedIn{id: user.id,
                     timestamp: DateTime.utc_now()}
  end

  def execute(user, %Commands.Logout{}) do
    %Events.LoggedOut{id: user.id,
                     timestamp: DateTime.utc_now()}
  end

  def execute(%__MODULE__{hubspot_contact_id: nil}, c = %Commands.CreateHubspotContact{}) do
    %Events.HubspotContactCreated{id: c.id, contact_id: c.contact_id}
  end

  def execute(_, %Commands.CreateHubspotContact{}) do
    {:error, :hubspot_contact_already_created}
  end

  def execute(_, c = %Commands.UpdateTimezone{}) do
    %Events.TimezoneUpdated{id: c.id, timezone: c.timezone}
  end

  # Inviting an existing user without an associated account
  def execute(user = %__MODULE__{user_account_id: nil}, c = %Commands.CreateInvite{}) do
    if Enum.any?(user.invites, &(&1.account_id === c.account_id)) do
      {:error, :user_already_invited}
    else
      create_invite(user, c.account_id, c.invite_id, c.inviter_id)
    end
  end

  def execute(_user, %Commands.CreateInvite{}) do
    {:error, :user_has_account}
  end

  # Add any commands that cannot be run on new users below this.
  def execute(%__MODULE__{id: nil}, c) do
    raise "Tried to execute command on an unknown user.\ncommand: #{inspect c}"
  end

  def execute(user, c = %Commands.DeleteInvite{}) do
    if Enum.any?(user.invites, &(&1.id === c.invite_id)) do
      %Events.InviteDeleted{id: user.id,
                            invite_id: c.invite_id,
                            account_id: c.account_id}
    else
      nil
    end
  end

  def execute(user = %__MODULE__{user_account_id: nil}, c = %Commands.AcceptInvite{}) do
    case Enum.find(user.invites, &(&1.id == c.invite_id)) do
      nil -> nil
      invite -> %Events.InviteAccepted{id: user.id,
                                       invite_id: c.invite_id,
                                       account_id: invite.account_id,
                                       accepted_at: c.accepted_at}
    end

  end

  def execute(_user, %Commands.AcceptInvite{}) do
    nil
  end

  def execute(user, %Commands.MakeAdmin{}) do
    %Events.MadeAdmin{id: user.id}
  end

  def execute(user, %Commands.RepealAdmin{}) do
    %Events.RepealedAdmin{id: user.id}
  end

  def execute(user, c = %Commands.SetReadOnly{}) do
    if user.is_read_only? != c.is_read_only do
      %Events.ReadOnlySet{id: user.id, is_read_only: c.is_read_only}
    end
  end

  def execute(user, _ = %Commands.Print{}) do
    IO.inspect(user)
    nil
  end

  def execute(user, c = %Commands.UpdateAuth0Info{}) do
    if user.uid != c.uid, do: make_event(c, Events.Auth0InfoUpdated)
  end

  def execute(user, c = %Commands.UpdateSlackDetails{}) do
    if user.last_seen_slack_team_id != c.last_seen_slack_team_id || user.last_seen_slack_user_id != c.last_seen_slack_user_id do
      make_event(c, Events.SlackDetailsUpdated)
    end
  end

  def execute(user, c = %Commands.SendMonitorSubscriptionReminder{}) do
    # Only send if we haven't sent for this monitor before
    # If this item comes in within 10s of another request, don't DM them again but mark that monitor as sent (can happen when multiple monitors are selected )
    if !Enum.any?(user.monitor_subscription_reminders, &(&1.monitor_logical_name === c.monitor_logical_name)) do
      make_event(c, Events.SubscriptionReminderSent)
      |> Map.put(:sent_at, NaiveDateTime.utc_now())
      |> Map.put(:is_silent, should_subscription_reminder_be_silenced?(user) )
    end
  end

  def execute(_user, c = %Commands.ClearSubscriptionReminders{}) do
    make_event(c, Events.SubscriptionRemindersCleared)
  end

  def execute(_, c = %Commands.UpdateEmail{}) do
    e = %Events.EmailUpdated{id: c.id, email: c.email}
    Domain.CryptUtils.encrypt(e, "user")
  end

  # Event handling
  def apply(self, e = %Events.Created{}) do
    %__MODULE__{self |
                id: e.id,
                user_account_id: e.user_account_id,
                email: e.email,
                uid: e.uid,
                invites: [],
                is_metrist_admin?: false,
                is_read_only?: e.is_read_only}
  end

  def apply(self, e = %Events.Updated{}) do
    Logger.warn("Events.Updated is deprecated, see Domain.User.Events.AccountIdUpdate")
    %__MODULE__{self |
                user_account_id: e.user_account_id}
  end

  def apply(self, e = %Events.AccountIdUpdate{}) do
    %__MODULE__{self |
                user_account_id: e.user_account_id}
  end

  def apply(self, %Events.LoggedIn{}) do
    self
  end

  def apply(self, %Events.DatadogLoggedIn{}) do
    self
  end

  def apply(self, %Events.LoggedOut{}) do
    self
  end

  def apply(self, e = %Events.HubspotContactCreated{}) do
    %__MODULE__{self | hubspot_contact_id: e.contact_id}
  end

  def apply(self, e = %Events.TimezoneUpdated{}) do
    %__MODULE__{self | timezone: e.timezone}
  end

  def apply(self, e = %Events.InviteCreated{}) do
    %__MODULE__{self |
                invites: [
                  %Invite{id: e.invite_id, inviter_id: e.inviter_id, account_id: e.account_id}
                  | self.invites
                ]}
  end

  def apply(self, e = %Events.InviteDeleted{}) do
    %__MODULE__{self |
                id: e.id,
                invites: Enum.reject(self.invites, &(&1.id === e.invite_id))}
  end

  def apply(self, e = %Events.InviteAccepted{}) do
    %__MODULE__{self |
                user_account_id: e.account_id
                }
  end

  def apply(self, %Events.MadeAdmin{}) do
    %__MODULE__{self | is_metrist_admin?: true}
  end

  def apply(self, %Events.RepealedAdmin{}) do
    %__MODULE__{self | is_metrist_admin?: false}
  end

  def apply(self, e = %Events.ReadOnlySet{}) do
    %__MODULE__{self | is_read_only?: e.is_read_only}
  end

  def apply(self, e = %Events.Auth0InfoUpdated{}) do
    %__MODULE__{self | uid: e.uid}
  end

  def apply(self, e = %Events.SlackDetailsUpdated{}) do
    %__MODULE__{self | last_seen_slack_team_id: e.last_seen_slack_team_id, last_seen_slack_user_id: e.last_seen_slack_user_id}
  end

  def apply(self, e = %Events.SubscriptionReminderSent{}) do
    %__MODULE__{self | monitor_subscription_reminders: [
      %SubscriptionReminder{ monitor_logical_name: e.monitor_logical_name, sent_at: NaiveDateTime.utc_now() } | self.monitor_subscription_reminders
    ]}
  end

  def apply(self, _ = %Events.SubscriptionRemindersCleared{}) do
    %__MODULE__{self | monitor_subscription_reminders: []}
  end

  def apply(self, e = %Events.EmailUpdated{}) do
    %__MODULE__{self | email: e.email}
  end
  # Event helpers

  defp create_user(_user, id, user_account_id, email, uid, is_read_only) do
    e = %Events.Created{id: id,
                    user_account_id: user_account_id,
                    email: email,
                    uid: uid,
                    is_read_only: is_read_only}
    Domain.CryptUtils.encrypt(e, "user")
  end

  defp create_invite(user, account_id, invite_id, inviter_id) do
    %Events.InviteCreated{id: user.id,
                          account_id: account_id,
                          invite_id: invite_id,
                          inviter_id: inviter_id}
  end

  defp remove_invites_for_account_if_required(user, c = %Commands.Update{}) do
    if (c.user_account_id == nil) do
      # Clear invites for the account that is being removed so they can be re-invited in the future
      Enum.filter(user.invites, &(&1.account_id === user.user_account_id))
      |> Enum.map(&%Events.InviteDeleted{id: user.id,
        invite_id: &1.id,
        account_id: user.user_account_id}
      )
    else
      []
    end
  end

  defp should_subscription_reminder_be_silenced?(user) do
    # If we sent any previous reminder in the last 10 seconds then the next message should be silenced
    Enum.any?(user.monitor_subscription_reminders, &(NaiveDateTime.diff(NaiveDateTime.utc_now(), &1.sent_at) < 10))
  end
end
