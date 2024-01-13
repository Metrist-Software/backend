defmodule Domain.User.Commands do
  use TypedStruct

  typedstruct module: Create do
    use Domo
    field :id, String.t, enforce: true
    field :user_account_id, String.t
    field :email, String.t, enforce: true
    field :uid, String.t
    field :is_read_only, boolean, default: false
  end

  typedstruct module: Update do
    use Domo
    field :id, String.t, enforce: true
    field :user_account_id, String.t
  end

  typedstruct module: Login do
    use Domo
    field :id, String.t, enforce: true
  end

  typedstruct module: DatadogLogin do
    use Domo
    field :id, String.t, enforce: true
  end

  typedstruct module: Logout do
    use Domo
    field :id, String.t, enforce: true
  end

  typedstruct module: CreateInvite do
    use Domo
    field :id, String.t, enforce: true
    field :email, String.t, enforce: true
    field :account_id, String.t, enforce: true
    field :invite_id, String.t, enforce: true
    field :inviter_id, String.t, enforce: true
  end

  typedstruct module: DeleteInvite do
    use Domo
    field :id, String.t, enforce: true
    field :invite_id, String.t, enforce: true
    field :account_id, String.t, enforce: true
  end

  typedstruct module: AcceptInvite, enforce: true do
    use Domo
    field :id, String.t()
    field :invite_id, String.t()
    field :accepted_at, NaiveDateTime.t()
  end

  typedstruct module: MakeAdmin, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: RepealAdmin, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: SetReadOnly, enforce: true do
    use Domo
    field :id, String.t
    field :is_read_only, boolean()
  end

  typedstruct module: Print, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: UpdateAuth0Info, enforce: true do
    use Domo
    field :id, String.t
    field :uid, String.t
  end

  typedstruct module: UpdateSlackDetails, enforce: true do
    use Domo
    field :id, String.t
    field :last_seen_slack_team_id, String.t
    field :last_seen_slack_user_id, String.t
  end

  typedstruct module: SendMonitorSubscriptionReminder, enforce: true do
    use Domo
    field :id, String.t
    field :monitor_logical_name, String.t
    field :monitor_name, String.t
  end

  typedstruct module: ClearSubscriptionReminders, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: CreateHubspotContact, enforce: true do
    use Domo
    field :id, String.t
    field :contact_id, String.t
  end

  typedstruct module: UpdateTimezone, enforce: true do
    use Domo
    field :id, String.t
    field :timezone, String.t
  end

  typedstruct module: UpdateEmail, enforce: true do
    @moduledoc """
    This command allows a pure functional way of changing the email on an aggregate.
    Anything that dispatches this command, should have already done the proper projection/db
    level validation that the email is unique. The aggregate itself can't query the other user
    aggregates or the DB to ensure this is the case. This command will happily execute to change
    an email to another email that already exist.
    """
    use Domo
    field :id, String.t, enforce: true
    field :email, String.t
  end
end
