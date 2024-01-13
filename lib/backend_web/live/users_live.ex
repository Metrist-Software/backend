defmodule BackendWeb.UsersLive do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, session, socket) do
    account = Backend.Projections.get_account(session["current_user"].account_id)
    users_with_invites = Backend.Projections.list_users_with_invites(account.id)
    socket =
      socket
      |> assign(
        account: account,
        page_title: "Users",
        email: "",
        selected_invites: [],
        selected_users: [],
        active_users: active_users(users_with_invites),
        pending_invite_users: pending_invite_users(users_with_invites))

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("invite-change", _, socket) do
    {:noreply, clear_flash(socket)}
  end

  @impl true
  def handle_event("invite-send", %{"email-input" => email}, socket) do
    invite_id = Domain.Id.new()

    invitee_id = case Backend.Projections.user_by_email(email) do
      nil -> Domain.Id.new()
      user -> user.id
    end

    cmd = %Domain.User.Commands.CreateInvite{
      id: invitee_id,
      email: email,
      invite_id: invite_id,
      inviter_id: socket.assigns.current_user.id,
      account_id: socket.assigns.account.id}

    case BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) do
      :ok -> {:noreply, socket
                        |> assign(
                          pending_invite_users: [%{
                            id: invitee_id,
                            invite_id: invite_id,
                            email: email,
                            inviter_id: socket.assigns.current_user.id,
                            inviter_email: socket.assigns.current_user.email,
                            invite_accepted_at: nil,
                            invited_at: NaiveDateTime.utc_now()
                          } | socket.assigns.pending_invite_users]
                          |> Enum.sort_by(&(&1.email))
                        )}
      {:error, :user_has_account} -> {:noreply, put_flash(socket, :error, "User already belongs to an account")}
      {:error, :user_already_invited} -> {:noreply, put_flash(socket, :error, "User already invited")}
      {:error, :read_only_user} -> {:noreply, socket}
    end
  end

  # Select All/None events
  @impl true
  def handle_event("pending-invites-change", %{"_target" => ["invites-all"], "invites-all" => "on"}, socket) do
    {:noreply, assign(socket, selected_invites: Enum.map(socket.assigns.pending_invite_users, &(&1.id)))}
  end

  @impl true
  def handle_event("pending-invites-change", %{"_target" => ["invites-all"]}, socket) do
    {:noreply, assign(socket, selected_invites: [])}
  end

  @impl true
  def handle_event("active-users-change", %{"_target" => ["users-all"], "users-all" => "on"}, socket) do
    {
      :noreply,
      assign(socket,
        selected_users: Enum.reject(socket.assigns.active_users, &(is_undeletable_id(&1, socket))) |> Enum.map(&(&1.id))
      )
    }
  end

  @impl true
  def handle_event("active-users-change", %{"_target" => ["users-all"]}, socket) do
    {:noreply, assign(socket, selected_users: [])}
  end


  # Select/Deselect specific item events
  @impl true
  def handle_event("pending-invites-change", map = %{"_target" => [id]}, socket) when is_map_key(map, id) do
    # map contains the invite as a key, will only be present when checkbox is selected
    socket = unless Enum.member?(socket.assigns.selected_invites, id) do
      assign(socket, selected_invites: [id | socket.assigns.selected_invites])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("pending-invites-change", %{"_target" => [id]}, socket) do
    {:noreply, assign(socket, selected_invites: List.delete(socket.assigns.selected_invites, id))}
  end

  @impl true
  def handle_event("active-users-change", map = %{"_target" => [id]}, socket) when is_map_key(map, id) do
    socket = unless Enum.member?(socket.assigns.selected_users, id) or id == socket.assigns.current_user.id do
      assign(socket, selected_users: [id | socket.assigns.selected_users])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("active-users-change", %{"_target" => [id]}, socket) do
    {:noreply, assign(socket, selected_users: List.delete(socket.assigns.selected_users, id))}
  end

  # Remove events
  @impl true
  def handle_event("pending-invites-delete", _, socket) do
    pending_invited_users = socket.assigns.selected_invites
      |> Enum.map(fn id -> Enum.find(socket.assigns.pending_invite_users, &(&1.id === id)) end)

    for user <- pending_invited_users do
      cmd = %Domain.User.Commands.DeleteInvite{
        id: user.id,
        invite_id: user.invite_id,
        account_id: socket.assigns.account.id}

        BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)
    end

    remaining_pending_invite_users = socket.assigns.pending_invite_users
    |> Enum.filter(&(!Enum.member?(socket.assigns.selected_invites, &1.id)))

    {:noreply, assign(socket,
                    pending_invite_users: remaining_pending_invite_users,
                    selected_invites: [])}
  end

  @impl true
  def handle_event("active-users-delete", _, socket) do
    users_to_delete = socket.assigns.selected_users
      |> Enum.map(fn id -> Enum.find(socket.assigns.active_users, &(&1.id === id)) end)
      |> Enum.reject(&(is_undeletable_id(&1, socket)))

    for user <- users_to_delete do
      cmd = %Domain.Account.Commands.RemoveUser{
        id: socket.assigns.account.id,
        user_id: user.id
      }

      # Delete the user from auth0 if they exists
      # Not in the Account event handler because replaying that stream
      # would mean that any user who ever got removed from any account
      # would have their auth0 account deleted along with their history
      # on that platform
      case BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) do
        {:error, _} ->
          nil
        _ ->
          Backend.Auth.Auth0.try_delete_user(user.uid)
      end
    end

    remaining_active_users = socket.assigns.active_users
    |> Enum.filter(&(!Enum.member?(socket.assigns.selected_users, &1.id)))

    {:noreply, assign(socket,
                    active_users: remaining_active_users,
                    selected_users: [])}
  end

  defp pending_invite_users(user_with_invites), do: Enum.filter(user_with_invites, fn u -> u.invite_id && !u.invite_accepted_at end) |> Enum.sort_by(&(&1.email))

  defp active_users(user_with_invites), do: Enum.filter(user_with_invites, fn u -> !u.invite_id || u.invite_accepted_at end) |> Enum.sort_by(&(&1.email))

  defp select_all_active_for_users?(selected_users, active_users, current_user, account) do
    deletable_user_ids = active_users
    |> Enum.reject(&(is_undeletable_id(&1, current_user, account)))
    length(selected_users) == length(deletable_user_ids)
  end

  defp is_undeletable_id(user, socket) do
    is_undeletable_id(user, socket.assigns.current_user, socket.assigns.account)
  end
  defp is_undeletable_id(user = %{}, current_user, account) do
    is_undeletable_id(user.id, current_user, account)
  end
  defp is_undeletable_id(user_id, current_user, account) do
    Enum.member?([current_user.id, account.original_user_id], user_id)
  end
 end
