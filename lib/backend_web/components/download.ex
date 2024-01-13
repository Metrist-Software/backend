defmodule BackendWeb.Components.Download do
  use BackendWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(url: "https://docs.metrist.io/guides/orchestrator-installation")}
  end

  # For now, we only render when logged in
  @impl true
  def render(assigns = %{current_user: nil}) do
    ~H"""
    <div id={"download-#{@id}"}></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="nav-item flex w-full">
      <div class="p-1 fill-white rounded-full">
        <%= svg_image("icon-download") %>
      </div>
      <a class="ml-3 pr-5 " target="_blank" href={@url}>Download</a>
    </div>
    """
  end
end
