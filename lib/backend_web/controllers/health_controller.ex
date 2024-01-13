defmodule BackendWeb.HealthController do
  use BackendWeb, :controller

  def index(conn, _params) do
    text(conn, "OK\n")
  end
end
