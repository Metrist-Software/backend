defmodule BackendWeb.RedirectController do
  @moduledoc """
  Redirects route based on the given `to` path

  ## Example
      get "/monitors", RedirectController, :index, assigns: %{to: "/"}
  """

  use BackendWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: conn.assigns.to)
  end
end
