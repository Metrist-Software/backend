defmodule BackendWeb.AppsTeamsLive do
  use BackendWeb, :live_view
  alias Backend.Integrations.Teams

  # There's some overlap between this one and Slack's. Not really enough to
  # do something about it, I think.

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Install Teams App",
        show_instructions: false,
        complete: false,
        step_contents: nil,
        step_title: nil,
        tenants: [])

    {:ok, socket}
  end

  @impl true
  def handle_params(p = %{"callback" => _}, uri, socket) do
    # We have an external callback into a liveview, make sure we don't run the logic twice.
    if connected?(socket) and Map.has_key?(p, "state") do
      {:ok, _random} = Phoenix.Token.verify(BackendWeb.Endpoint, "teams", p["state"])
      # Cleanup the uri which we need to pass the callback uri again
      uri = String.replace(uri, ~r/\?.*/, "")

      result = with {:ok, tenant_uuid, tenant_name} <- Teams.tenant_info_from_oauth_code(p["code"], redirect_uri(uri)) do
        Teams.attach_workspace_to_account(account_id(socket), tenant_uuid, tenant_name)
      end

      # Handle_params cannot push_patch, so we handle that by sending ourselves a message
      case result do
        {:ok, cmd}  ->
          BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)
          {:noreply, push_patch(socket, to: Routes.apps_teams_path(socket, :complete))}
        {:error, {level, msg}} ->
          {:noreply, socket
                     |> assign(is_informational: (level == :info), message: msg)
                     |> push_patch(to: Routes.apps_teams_path(socket, :failed))
          }
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, socket
    |> assign(uri: uri)
    |> maybe_assign_tenants()
    |> assign_step_contents()
    |> assign_step_title()}
  end

  defp maybe_assign_tenants(socket) do
    case socket.assigns.live_action do
      :connect ->
        tenants =
          socket
          |> BackendWeb.Helpers.account_id()
          |> Backend.Projections.get_microsoft_tenants()
          assign(socket, tenants: tenants)
      _ -> socket
    end
  end

  defp assign_step_contents(%Phoenix.LiveView.Socket{assigns: assigns} = socket),
    do: assign(socket, :step_contents, step_contents(assigns.live_action, assigns))

  defp assign_step_title(%Phoenix.LiveView.Socket{assigns: assigns} = socket),
    do: assign(socket, :step_title, step_title(assigns.live_action))

  @impl true
  def handle_event("show-instructions", _params, socket) do
    {:noreply, socket
    |> assign(show_instructions: true)
    |> assign_step_contents()}
  end

  @impl true
  def handle_event("associate", _params, socket) do
    if socket.assigns.current_user.is_read_only do
      {:noreply, socket}
    else
      {:noreply, jump_to_teams(socket)}
    end
  end

  defp jump_to_teams(socket) do
    # We don't really care what we pass in. Any random number will do, it's the verification
    # we're interested in.
    cookie = :rand.uniform(1_000_000_000_000)
    token = Phoenix.Token.sign(BackendWeb.Endpoint, "teams", cookie)
    redirect(socket,
      external: Backend.Integrations.Teams.oauth_url(token, redirect_uri(socket)))
  end

  defp redirect_uri(%Phoenix.LiveView.Socket{assigns: assigns}), do: redirect_uri(assigns.uri)
  defp redirect_uri(uri), do: "#{uri}?callback=true"

  # Rendering

  @install_body (with priv_dir <- Application.app_dir(:backend, "priv"),
                       filename <- Path.join(priv_dir, "teams-install.md"),
                       contents <- File.read!(filename),
                       {:ok, html, _msgs} <- Earmark.as_html(contents) do
                    html
                  end)

 def render_connect(assigns) do
    assigns = Map.put(assigns, :body, {:safe, @install_body})
    assigns = Map.put_new(assigns, :show_instructions, false)
    ~H"""
    <%= if length(@tenants) > 0 do %>
    <div class="mb-5">
      <p class="mb-3"><%= str("pages.apps.teams.connectedTenants") %></p>
      <ul class="list-disc list-inside">
      <%= for tenant <- @tenants do %>
        <li><%= tenant.team_name %></li>
      <% end %>
      </ul>
    </div>
    <% end %>

    <%= if @current_user.is_read_only do %>
    <p class="mb-3">You do not have the permissions to connect Teams on this account.</p>
    <% end %>

    <%= if not @current_user.is_read_only do %>

      <div class="mb-5 prose dark:prose-dark">
      Connecting Metrist on Teams is a two step process. You will first need to
      connect Metrist to Teams by signing in to Azure AD with the same account you use
      to sign into Teams.
      </div>

      <button id="associate-teams" class={button_class()}
              phx-click="associate">
        <%= str("actions.getStarted") %>
      </button>

      <div class="my-5 prose dark:prose-dark">
      Once Metrist is connected, follow these instructions to install the app in Teams.
      </div>

      <%= if @show_instructions do %>
        <div class="prose dark:prose-dark">
          <%= @body %>
        </div>
      <%  else %>
        <button id="show-instructions" class={button_class("secondary")}
                phx-click="show-instructions">
          <%= str("actions.teamsInstructions") %>
        </button>
      <%  end %>

    <% end %>
    """
  end

  def render_complete(assigns) do
    assigns = Map.put(assigns, :body, {:safe, @install_body})
    ~H"""
    <div class="mb-5 prose dark:prose-dark">
      <p>
        <%= str("pages.apps.teams.complete.description") %>
      </p>

      <p>
        <%= str("pages.apps.teams.complete.getStarted") %>
      </p>
    </div>

    <div class="prose dark:prose-dark">
      <%= @body %>
    </div>
    """
  end

  def render_failed(assigns) do
    ~H"""
    <p class="mb-5"><%= str("pages.apps.teams.callback.failure") %></p>
    <.alert color={if assigns.is_information, do: "info", else: "danger"} label={assigns.message} />
    <button class={button_class()}
            onclick={ "window.location.href='#{Routes.apps_teams_path(BackendWeb.Endpoint, :connect)}';" }>Try again</button>
    """
  end

  # Step helpers

  @steps %{
    connect: 0,
    complete: 2,
    failed: 2
  }

  def step_of(live_action) do
    Map.get(@steps, live_action)
  end

  def step_contents(live_action, assigns) do
    fun =
      case live_action do
        :connect -> &render_connect/1
        :complete -> &render_complete/1
        :failed -> &render_failed/1
      end

    fun.(assigns)
  end

  def step_title(live_action) do
    key = case live_action do
        :connect -> "pages.apps.teams.title"
        :complete -> "pages.apps.teams.complete.title"
        :failed -> "pages.apps.teams.failed.title"
      end

    BackendWeb.I18n.str(key)
  end
end
