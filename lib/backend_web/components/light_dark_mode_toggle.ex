defmodule BackendWeb.Components.LightDarkModeToggle do
  use BackendWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, mode: :light, title: "Light Mode")}
  end

  def render(assigns=%{inner_block: _}) do
    ~H"""
    <span id="light-dark-mode-toggle" phx-hook="ToggleLightDarkMode">
      <%= render_slot(@inner_block, {@myself, @mode}) %>
    </span>
    """
  end

  def render(assigns) do
    ~H"""
    <button
      id="light-dark-mode-toggle-button"
      class="nav-item w-full sm:w-auto sm:px-2"
      active-class="nav-item-active"
      phx-click="push-toggle"
      phx-target={@myself}
      phx-hook="ToggleLightDarkMode"
      title={@title}>
        <%= svg_image("icon-#{@mode}-mode", class: "w-5 h-5") %>
        <span class="ml-3 sm:sr-only"><%= @title %></span>
    </button>
    """
  end

  def handle_event("push-toggle", _params, socket) do
    {:noreply,
      socket
      |> update_mode()
      |> push_event("toggle-light-dark-mode", %{id: socket.assigns.id})}
  end

  def handle_event("toggle-light-dark-mode", _params, socket) do
    {:noreply, update_mode(socket)}
  end

  def update_mode(socket) do
    {mode, title} = case socket.assigns.mode do
      :dark -> {:light, "Light Mode"}
      :light -> {:dark, "Dark Mode"}
    end

    assign(socket, mode: mode, title: title)
  end
end
