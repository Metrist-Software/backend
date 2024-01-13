defmodule BackendWeb.SlackLoginController do
  use BackendWeb, :controller

  require Logger

  @moduledoc """
  Handles user interaction with explore button in a Slack service health message.

  A logged in Metrist user is taken directly to the corresponding dependency
  page, otherwise they are authenticated via Auth0 and Slack before being taken
  to the corresponding dependency page.
  """

  def slack_login(conn, %{"slack_team_id" => slack_team_id, "redirect_monitor" => redirect_monitor}) do
    path = BackendWeb.Router.Helpers.live_path(BackendWeb.Endpoint, BackendWeb.MonitorDetailLive, redirect_monitor)

    ensure_conn_is_up_to_date(conn)
    |> get_session(:current_user)
    |> maybe_authenticate_user(
      conn,
      slack_team_id,
      redirect_monitor,
      path
      )
  end

  defp maybe_authenticate_user( _user = nil, conn, slack_team_id, redirect_monitor, path) do
    conn
    |> put_session(:auth_redirect, "#{path}")
    |> redirect(to: Routes.auth_path(
      BackendWeb.Endpoint,
      :request, "auth0",
      login_hint: slack_team_id,
      connection: Backend.config([BackendWeb.LoginLive, :open_id_connection_name]),
      slack_team_id: slack_team_id,
      redirect_monitor: redirect_monitor
      ))
  end

  defp maybe_authenticate_user(_user, conn, _slack_team_id, _redirect_monitor, path) do
    conn
    |> redirect(to: "#{path}")
    |> halt()
  end

  defp ensure_conn_is_up_to_date(conn) do
    case ensure_user_is_up_to_date(conn) do
      {:ok, _user} -> conn
      {:updated, user} -> put_session(conn, :current_user, user)
    end
  end

  defp ensure_user_is_up_to_date(conn) do
    get_session(conn, :current_user)
    |> BackendWeb.Helpers.get_up_to_date_user()
  end

end
