defmodule BackendWeb.InitAssigns do
  use BackendWeb, :live_view

  def on_mount(user_type, _params, session, socket) do
    socket = copy_session(socket, session)

    if require_user_type(user_type, socket) do
      socket =
        socket
        |> attach_path_parse_hook()
        |> attach_read_only_user_hook()
        |> get_notices()
        |> assign(static_changed?: static_changed?(socket))

      maybe_subscribe_to_user_events(socket)

      {:cont, socket}
    else
      {:halt, redirect(socket, to: redirect_path(user_type))}
    end
  end

  def render(assigns) do
    ~H""
  end

  @redirects %{
    user: "/signup/account"
  }
  defp redirect_path(user_type) do
    Map.get(@redirects, user_type, "/")
  end

  def attach_path_parse_hook(socket) do
    attach_hook(socket, :set_active_path, :handle_params, fn
      _params, url, socket ->
        {:cont, assign(socket, __path__: URI.parse(url).path)}
    end)
  end

  def attach_read_only_user_hook(socket) do
    attach_hook(socket, :read_only_user_redirect, :handle_info, fn
      _ = %{event: %Domain.User.Events.ReadOnlySet{}}, socket ->
        {:halt, redirect(socket, to: "/auth/reauth")}

      _info, socket ->
        {:cont, socket}
    end)
  end

  @doc """
  Copy everything we need from the session into the socket
  """
  def copy_session(socket, session) do
    session_current_user = session["current_user"]
    spoofing? = session["spoofing?"]

    current_user =
      cond do
        is_nil(session_current_user) ->
          session_current_user

        spoofing? ->
          user = maybe_get_user!(session_current_user)

          %Backend.Projections.User{
            user
            | account_id: session_current_user.account_id,
              is_metrist_admin: session_current_user.is_metrist_admin
          }

        true ->
          maybe_get_user!(session_current_user)
      end

    Phoenix.Component.assign(socket,
      current_user: current_user,
      spoofing?: spoofing?,
      spoofed_account_name: session["spoofed_account_name"]
    )
  end

  def maybe_get_user!(%{id: id} = session) do
    case Backend.Projections.User.get_user!(id) do
      nil ->
        # creating a user from slack explore button doesn't show up in projections immediately, so return session user as a precaution instead
        session
      user -> user
    end
  end
  def maybe_get_user!(_current_user), do: nil

  defp get_notices(socket) do
    notices =
      with true <- connected?(socket),
           user when not is_nil(user) <- socket.assigns.current_user,
           %{id: user_id} when not is_nil(user_id) <- user,
           %{account_id: account_id} when not is_nil(account_id) <- user do
        Backend.Projections.Notice.active_notices_for_user(user_id)
      else
        _ -> []
      end

    assign(socket, banner_notices: notices)
  end

  defp maybe_subscribe_to_user_events(%{assigns: %{current_user: %{id: user_id}}})
       when not is_nil(user_id) do
    topic = "User:#{user_id}"
    Backend.PubSub.unsubscribe(topic)
    Backend.PubSub.subscribe(topic)
  end

  defp maybe_subscribe_to_user_events(_socket), do: nil

  defp require_user_type(:public, _socket), do: true
  defp require_user_type(:everyone, _socket), do: true
  defp require_user_type(:new_user, %{assigns: %{current_user: %{account_id: nil}}}), do: true

  defp require_user_type(:user, %{assigns: %{current_user: %{account_id: account_id}}})
       when not is_nil(account_id),
       do: true

  defp require_user_type(:not_read_only_user, %{assigns: %{current_user: %{is_read_only: false}}}),
    do: true

  defp require_user_type(:admin, %{assigns: %{current_user: %{is_metrist_admin: true}}}), do: true
  defp require_user_type(_type, _socket), do: false
end
