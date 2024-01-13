defmodule BackendWeb.PlaygroundLive do
  use BackendWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Component Playground")

    {:ok, socket}
  end
end
