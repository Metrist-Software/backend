defmodule BackendWeb.AuthController do
  use BackendWeb, :controller
  require Logger
  plug Ueberauth, otp_app: :backend_web

  action_fallback BackendWeb.FallbackController

  alias Ueberauth.Strategy.Helpers
  def request(conn, _params) do
    if conn.private[:ueberauth_request_options] do
      redirect(conn, to: Helpers.callback_url(conn))
    else
      {:error, :not_found}
    end
  end

  def delete(conn, _params) do
    port_part = port_part(conn.scheme, conn.port)
    login_url = "#{conn.scheme}://#{conn.host}#{port_part}"
    user_id = get_session(conn, "current_user").id

    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(conn, %Domain.User.Commands.Logout{
      id: user_id})

    BackendWeb.Endpoint.broadcast("users_socket:#{user_id}", "disconnect", %{})

    conn
    |> put_flash(:info, "You have been logged out!")
    |> clear_session()
    |> redirect(external: Backend.Auth.Auth0.logout_url(login_url))
  end

  def spoof(conn, %{"account_id" => account_id, "account_name" => account_name}) do
    {status, user} = get_session(conn, :current_user)
    |> BackendWeb.Helpers.get_up_to_date_user()
    conn = case status do
      :ok -> conn
      :updated -> put_session(conn, :current_user, user)
    end
    IO.inspect(user, label: "user")
    conn
    |> put_flash(:info, "Spoofing session started")
    |> put_session(:spoofing?, true)
    |> put_session(:original_account_id, user.account_id)
    |> put_session(:spoofed_account_name, account_name)
    |> put_session(:current_user, %Backend.Projections.User{user |
                                                           account_id: account_id,
                                                           is_metrist_admin: false})
    |> redirect(to: "/")
  end

  def unspoof(conn, _params) do
    IO.inspect(get_session(conn), label: "session")
    if get_session(conn, "spoofing?") do
      {status, user} = get_session(conn, :current_user)
      |> BackendWeb.Helpers.get_up_to_date_user()
      conn = case status do
        :ok -> conn
        :updated -> put_session(conn, :current_user, user)
      end
      original_account_id = get_session(conn, "original_account_id")
      conn
      |> put_flash(:info, "Spoofing session ended")
      |> put_session(:spoofing?, false)
      |> delete_session(:original_account_id)
      |> delete_session(:spoofed_account_name)
      |> put_session(:current_user, %Backend.Projections.User{user |
                                                             account_id: original_account_id,
                                                             is_metrist_admin: true})
      |> redirect(to: "/admin/accounts")
    else
      # Someone manually constructed the request, ignore it.
      redirect(conn, to: "/")
    end
  end

  # Alas, even though the methods are named the same between oldskool and LiveView, they
  # don't act the same but we want to give both parts of the app the same call.
  @type sock_or_conn ::  Plug.Conn.t() | Phoenix.LiveView.Socket.t()
  @spec login_with_no_account(sock_or_conn, %Backend.Projections.User{}) :: sock_or_conn
  def login_with_no_account(sock = %Phoenix.LiveView.Socket{}, user) do
    login_with_no_account(sock, user, &Phoenix.LiveView.put_flash/3, &Phoenix.LiveView.redirect/2)
  end
  def login_with_no_account(conn = %Plug.Conn{}, user) do
    login_with_no_account(conn, user, &Phoenix.Controller.put_flash/3, &Phoenix.Controller.redirect/2)
  end
  defp login_with_no_account(sock_or_conn, user, put_flash_fun, redirect_fun) do
    if Backend.UserFromAuth.is_verified(user) do
      sock_or_conn
      |> redirect_fun.(to: "/signup/monitors")
    else
      sock_or_conn
      |> put_flash_fun.(:info, "Before continuing the signup process, please verify your email address using the instructions in the email we sent or use the \"Resend Verification Email\" button below to send it again.")
      |> redirect_fun.(to: "/signup/verify")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> IO.inspect()
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  # logins via slack explore button
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"slack_team_id" => slack_team_id, "redirect_monitor" => redirect_monitor} = params) do
    case slack_team_id == auth.extra.raw_info.user["https://slack:com/team_id"] do
      true ->
        try_login(conn, auth, params, true)
      _ ->
        conn
        |> put_flash(:error, "Incorrect workspace, please sign in again.")
        |> redirect(to: Routes.live_path(BackendWeb.Endpoint, BackendWeb.SlackLoginRetryLive, slack_team_id, redirect_monitor))
    end
  end

  # logins with invite or normal
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
    try_login(conn, auth, params, false)

  end


  defp try_login(conn, auth, params, slack_login_from_explore_button?) do
    redir =
      case get_session(conn, "auth_redirect") do
        nil ->
          IO.puts("==> no redirect path")
          "/"
        path ->
          IO.puts("==> redirect to #{path}")
          path
      end

    case Backend.UserFromAuth.find_or_create(auth, slack_login_from_explore_button?) do
      {:ok, user} ->
        user = try_accept_invite(user, params)

        conn
        |> put_session(:current_user, user)
        |> put_session(:live_socket_id, "users_socket:#{user.id}")
        |> put_session(:spoofing?, false)
        |> put_session(:verified, true)
        |> configure_session(renew: true)
        |> redirect(to: redir)

      {:error, :existing_email_not_verified, user} ->
        # in this case we still need to try to accept an invite
        # TODO: if they came in with an invite code from their email
        # we probably don't need to verify their email.
        # Will deal with that in a separate ticket.
        user = try_accept_invite(user, params)

        conn
        |> put_session(:current_user, user)
        |> put_session(:live_socket_id, "users_socket:#{user.id}")
        |> put_session(:spoofing?, false)
        |> put_session(:verified, false)
        |> redirect(to: "/verify")
    end
  end

  defp try_accept_invite(user, %{"invite_id" => invite_id}) when invite_id != "" do
    cmd = %Domain.User.Commands.AcceptInvite{
      id: user.id,
      invite_id: invite_id,
      accepted_at: NaiveDateTime.utc_now()
    }
    {:ok, %{aggregate_state: agg}} = Backend.Auth.CommandAuthorization.dispatch_with_auth_check(user, cmd, include_execution_result: true)

    Map.put(user, :account_id, agg.user_account_id)
  end

  defp try_accept_invite(user, _params) do
    user
  end

  # Someone requested to pull the user again, this can happen e.g. during signup
  # where a user starts with no account id and then joins an account at the end
  # of signup. If it all matches, reset the session.
  def reauth(conn, _params) do
    case get_session(conn, :current_user) do
      nil ->
        redirect(conn, to: "/login")
      user ->
        conn = if !get_session(conn, :verified) do
          put_session(conn, :verified, Backend.UserFromAuth.is_verified(user))
        else
          conn
        end

        user = Backend.Projections.user_by_email(user.email)
        conn
        |> put_session(:spoofing?, false)
        |> put_session(:current_user, user)
        |> redirect(to: "/")
    end
  end

  defp port_part(:https, 443), do: ""
  defp port_part(:http, 80), do: ""
  defp port_part(_, port), do: ":#{port}"
end
