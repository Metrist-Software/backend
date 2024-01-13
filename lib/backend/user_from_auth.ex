defmodule Backend.UserFromAuth do
  require Logger
  alias Backend.Projections.User
  alias Domain.User.Commands, as: UserCmds
  alias Backend.Integrations.Hubspot
  @moduledoc """
  Helper module to find or create a user based on a successful
  Ueberauth login.
  """


  def find_or_create(auth, slack_login_from_explore_button?) do
    email = auth.info.email
    user_response = case Backend.Projections.user_by_email(email) do
      nil ->
        # Create user, return a fake one
        cmd = %Domain.User.Commands.Create{
          id: Domain.Id.new(),
          user_account_id:
            if slack_login_from_explore_button? do
              workspace = Backend.Projections.get_slack_workspace(auth.extra.raw_info.user["https://slack:com/team_id"])
              workspace.account_id
            end,
          email: email,
          uid: auth.uid,
          is_read_only: slack_login_from_explore_button?
        }
        Backend.Auth.CommandAuthorization.dispatch_with_auth_check(nil, cmd)
        # We can do two things here - wait for the projection to finish and retry
        # the read, or just fill out a user ourselves. Given that the data is simple,
        # we opt for the latter.
        user = %Backend.Projections.User{
          id: cmd.id,
          account_id: cmd.user_account_id,
          email: cmd.email,
          uid: cmd.uid,
          is_metrist_admin: false,
          is_read_only: cmd.is_read_only
        }
        |> update_slack_details(auth)
        # for slack_login flow, the account needs to add the user into the list of user_ids
        |> maybe_add_user_to_account(slack_login_from_explore_button?)

        {:ok, user}

      user ->
        update_uid_cmd = %Domain.User.Commands.UpdateAuth0Info {
          id: user.id,
          uid: auth.uid
        }
        user = %{user| uid: auth.uid}
        |> update_slack_details(auth)
        # for previously-registered users who were removed from the account, refill the account_id field
        # calls maybe_add_user_to_account in the function to add the user into the list of user_ids
        |> maybe_update_account_id_if_from_slack_explore(auth, slack_login_from_explore_button?)

        Backend.Auth.CommandAuthorization.dispatch_with_auth_check(user, update_uid_cmd)
        email_verified = Map.get(auth.extra.raw_info.user, "email_verified", true)
        if email_verified do
          {:ok, user}
        else
          {:error, :existing_email_not_verified, user}
        end
    end

    user = case user_response do
      {:ok, user} -> user
      {:error, _, user} -> user
    end
    |> ensure_hubspot_contact_exists()

    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(user, %Domain.User.Commands.Login{id: user.id})

    Hubspot.update_contact(user.hubspot_contact_id, %{
      "firstname" => auth.extra.raw_info.user["given_name"],
      "lastname" => auth.extra.raw_info.user["family_name"]
      })

    case user_response do
      {:ok, _} -> {:ok, user}
      {:error, error_atom, _} -> {:error, error_atom, user}
    end


  end


  defp maybe_add_user_to_account(user, _slack_login_from_explore_button? = true) do
    user = ensure_hubspot_contact_exists(user)

    account = Backend.Projections.get_account(user.account_id, [:original_user])
    Hubspot.update_contact(user.hubspot_contact_id, %{
      "metrist_user_acquisition" => "Invited",
      "metrist_account_id" => user.account_id,
      "metrist_account_name" => Backend.Projections.Account.get_account_name(account)})

    cmd = %Domain.Account.Commands.AddUser{
      id: user.account_id,
      user_id: user.id,
    }
    Backend.App.dispatch(cmd, metadata: %{actor: Backend.Auth.Actor.backend_code()})
    user
  end
  defp maybe_add_user_to_account(user, _slack_login_from_explore_button?) do
    user
  end

  defp maybe_update_account_id_if_from_slack_explore(%Backend.Projections.User{account_id: nil} = user, auth, _slack_login_from_explore_button? = true) do
    workspace = Backend.Projections.get_slack_workspace(auth.extra.raw_info.user["https://slack:com/team_id"])
    update_user_cmd =
      %Domain.User.Commands.Update {
        id: user.id,
        user_account_id: workspace.account_id
      }
    user = %{user| account_id: workspace.account_id}
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(user, update_user_cmd)
    user
    |> maybe_add_user_to_account(true)
  end
  defp maybe_update_account_id_if_from_slack_explore(user, _auth, _slack_login_from_explore_button?) do
    user
  end

  defp update_slack_details(user, auth) do
    #since team_id and user_id change simultaneously, arbitrarily choose team_id to check for nil on
    case auth.extra.raw_info.user["https://slack:com/team_id"] do
      nil -> user
      last_seen_slack_team_id ->
        update_slack_details_cmd =
          %Domain.User.Commands.UpdateSlackDetails {
            id: user.id,
            last_seen_slack_team_id: last_seen_slack_team_id,
            last_seen_slack_user_id: auth.extra.raw_info.user["https://slack:com/user_id"]
          }
        user = %{user| last_seen_slack_team_id: last_seen_slack_team_id, last_seen_slack_user_id: auth.extra.raw_info.user["https://slack:com/user_id"] }
        Backend.Auth.CommandAuthorization.dispatch_with_auth_check(user, update_slack_details_cmd)
        user
    end
  end

  defp ensure_hubspot_contact_exists(%Backend.Projections.User{hubspot_contact_id: nil} = user),
    do: Hubspot.create_contact(%{email: user.email}) |> ensure_hubspot_contact_exists(user)
  defp ensure_hubspot_contact_exists(user), do: user

  defp ensure_hubspot_contact_exists({:ok, contact_id}, user) do
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(nil, %UserCmds.CreateHubspotContact{id: user.id, contact_id: contact_id})
    # Same strategy as above. We could wait for the projection to finish or fill up the field ourselves
    %User{user | hubspot_contact_id: contact_id}
  end
  defp ensure_hubspot_contact_exists({:error, reason}, user) do
    Logger.error("Failed to create Hubspot contact for user_id: #{user.id}. Reason: #{reason}")
    user
  end

  def resend_verification_mail(%Backend.Projections.User{uid: uid}) do
    Backend.Auth.Auth0.resend_verification_mail(uid)
  end

  def is_verified(%Backend.Projections.User{uid: uid}) do
    Backend.Auth.Auth0.is_verified(uid)
  end
end
