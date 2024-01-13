defmodule BackendWeb.SignupController do
  use BackendWeb, :controller

  def index(conn, _params) do
    conn
    |> put_session(:auth_redirect, Routes.signup_path(conn, :monitors))
    |> redirect(to: Routes.login_path(BackendWeb.Endpoint, :signup))
  end

  def signup_redirect(conn, %{"connection" => connection}) do
    conn
    |> put_session(:auth_redirect, Routes.signup_path(conn, :monitors))
    |> redirect(to: Routes.auth_path(BackendWeb.Endpoint, :request, "auth0", screen_hint: "login", connection: connection))
  end
end
