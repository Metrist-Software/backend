defmodule BackendWeb.LoginLive do
  use BackendWeb, :blank_live_view
  require Logger

  @impl true
  def mount(%{"invite_id" => invite_id}, _session, socket) do
    Logger.info("----------- Running with invite_id #{invite_id} ---------------")
    socket =
      socket
      |> default_assigns()
      |> assign(
        invite_id: invite_id
      )

    {:ok,
      socket
      |> put_flash(:info, "You've been invited to join Metrist! Please choose your login provider below.")
    }
  end

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: :signup}} = socket) do
    Logger.info("----------- Running with signup ---------------")
    socket =
      socket
      |> default_assigns()
      |> assign(
        is_signup: true
      )

    {:ok,
    socket
    |> put_flash(:info, "To begin the signup process, please log in with your preferred login provider below.")
    }
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> default_assigns()

    {:ok, socket}
  end

  defp default_assigns(socket) do
    socket
    |> assign(
      invite_id: nil,
      is_signup: false,
      login_providers: [
      # { _imageName, _text, _auth0Connection },
        {"slack",     "Use your Slack account",     Backend.config([__MODULE__, :open_id_connection_name])},
        {"github",    "Use your GitHub account",    "github"},
        {"google",    "Use your Google account",    "google-oauth2"},
        {"microsoft", "Use your Microsoft account", "windowslive"},
        {"azuread",   "Use your Azure AD account",  "azuread"},
      ])
  end

  @impl true
  def handle_event("do-login", %{"provider" => provider}, socket) do
    {
      :noreply,
      redirect(socket, to: get_auth0_redirect(provider, %{
        invite_id: socket.assigns.invite_id,
        is_signup: socket.assigns.is_signup
      }))
    }
  end

  defp get_auth0_redirect(provider, %{invite_id: invite_id, is_signup: false}) do
    Routes.auth_path(BackendWeb.Endpoint, :request, "auth0", screen_hint: "login", connection: provider, invite_id: invite_id)
  end
  defp get_auth0_redirect(provider, %{invite_id: nil, is_signup: true}) do
    Routes.signup_path(BackendWeb.Endpoint, :signup_redirect, provider)
  end
  defp get_auth0_redirect(provider, %{invite_id: nil, is_signup: false}) do
    Routes.auth_path(BackendWeb.Endpoint, :request, "auth0", screen_hint: "login", connection: provider)
  end
end

