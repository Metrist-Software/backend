defmodule BackendWeb.AppsLive do
  use BackendWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Applications")

    {:ok, socket}
  end

  def handle_event("start-slack", _params, socket) do
    {:noreply, push_navigate(socket,
        to: Routes.apps_slack_path(socket, :start))}
  end

  def handle_event("start-teams", _params, socket) do
    {:noreply, push_navigate(socket,
        to: Routes.apps_teams_path(socket, :connect))}
  end
end
