defmodule BackendWeb.SlackLoginRetryLive do
  use BackendWeb, :live_view
  require Logger
  def mount(%{"slack_team_id" => slack_team_id, "redirect_monitor" => redirect_monitor}, _session, socket) do
    socket =
      socket
      |> assign(
        hide_breadcrumb: true,
        slack_team_id: slack_team_id,
        redirect_monitor: redirect_monitor)
    {:ok, socket}
  end

  def render(%{slack_team_id: slack_team_id} = assigns) do
    workspace = Backend.Projections.get_slack_workspace(slack_team_id)
    assigns = assign(assigns, :team_name, workspace.team_name)

    ~H"""
    <p>The link you are trying to access requires that you login through Slack to the <b><%= @team_name %></b> workspace.</p>
    <br>
    <p>You can try again below.</p>
    <br>
    <button phx-click="retry" class="btn btn-outline font-roboto">
      <%= BackendWeb.Helpers.Svg.svg_image("slack", "login", class: "inline mr-2 w-6 h-6") %>
      Sign in with Slack
    </button>
    """
  end

  def handle_event("retry", _params, socket) do
    url = Routes.slack_login_path(BackendWeb.Endpoint, :slack_login, socket.assigns.slack_team_id, socket.assigns.redirect_monitor)
    {:noreply, redirect(socket, to: url)}
  end

end
