defmodule Domain.User.Events do
  use TypedStruct

  typedstruct module: Created do
    use Domain.CryptUtils, fields: [:email]
    plugin Backend.JsonUtils
    field :id, String.t, enforce: true
    field :user_account_id, String.t
    field :email, String.t, enforce: true
    field :uid, String.t
    field :is_read_only, boolean, default: false, enforce: false
  end

  typedstruct module: Updated do
    @moduledoc "Deprecated: see `Domain.User.Events.AccountIdUpdate`"
    plugin Backend.JsonUtils
    field :id, String.t, enforce: true
    field :user_account_id, String.t
  end

  typedstruct module: AccountIdUpdate, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :user_account_id, String.t
  end

  typedstruct module: LoggedIn do
    plugin Backend.JsonUtils
    field :id, String.t, enforce: true
    field :timestamp, NaiveDateTime.t()
  end

  typedstruct module: DatadogLoggedIn do
    plugin Backend.JsonUtils
    field :id, String.t, enforce: true
    field :timestamp, NaiveDateTime.t()
  end

  typedstruct module: LoggedOut do
    plugin Backend.JsonUtils
    field :id, String.t, enforce: true
    field :timestamp, NaiveDateTime.t()
  end

  typedstruct module: InviteCreated do
    @derive Jason.Encoder
    field :id, String.t, enforce: true
    field :account_id, String.t, enforce: true
    field :invite_id, String.t, enforce: true
    field :inviter_id, String.t, enforce: true
  end

  typedstruct module: InviteDeleted do
    @derive Jason.Encoder
    field :id, String.t, enforce: true
    field :invite_id, String.t, enforce: true
    field :account_id, String.t, enforce: true
  end

  typedstruct module: InviteAccepted, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :invite_id, String.t()
    field :account_id, String.t()
    field :accepted_at, NaiveDateTime.t()
  end

  typedstruct module: MadeAdmin, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
  end

  typedstruct module: RepealedAdmin, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
  end

  typedstruct module: ReadOnlySet, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :is_read_only, boolean
  end

  typedstruct module: Auth0InfoUpdated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :uid, String.t
  end

  typedstruct module: SlackDetailsUpdated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :last_seen_slack_team_id, String.t
    field :last_seen_slack_user_id, String.t
  end

  typedstruct module: SubscriptionReminderSent, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t
    field :monitor_logical_name, String.t
    field :monitor_name, String.t
    field :is_silent, boolean
    field :sent_at, NaiveDateTime.t()
  end

  typedstruct module: SubscriptionRemindersCleared, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
  end

  typedstruct module: HubspotContactCreated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :contact_id, String.t
  end

  typedstruct module: TimezoneUpdated, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :timezone, String.t
  end

  typedstruct module: EmailUpdated, enforce: true do
    use Domain.CryptUtils, fields: [:email]
    plugin Backend.JsonUtils
    field :id, String.t
    field :email, String.t
  end

end
