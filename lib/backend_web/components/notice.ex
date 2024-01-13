defmodule BackendWeb.Components.Notice do
  use BackendWeb, :live_component
  alias Backend.Projections.Notice

  def mount(socket) do
    socket = assign(socket,
      notice: %Notice{},
      show_description: false,
      show_admin_controls: false
    )
    {:ok, socket}
  end

  def handle_event("toggle-description", _params, socket) do
    {:noreply, assign(socket, show_description: !socket.assigns.show_description)}
  end

  def handle_event("delete", _params, socket) do
    Backend.App.dispatch(%Domain.Notice.Commands.Clear{
      id: socket.assigns.notice.id
    })

    send(self(), {:notice_deleted, socket.assigns.notice.id})
    {:noreply, socket}
  end

  def handle_event("edit", _params, socket) do
    send(self(), {:notice_edit, socket.assigns.notice})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="mb-5 px-4 py-3 border rounded mb-5 bg-info-200 border-info-300 text-info-900">
      <div class="flex flex-row align-bottom">
        <p class="text-2xl">
          <%= @notice.summary %>

          <%= if !is_nil(@notice.end_date) do %>
          <span class="text-sm text-muted">(Until <%= Timex.format!(@notice.end_date, "{Mshort} {D}, {YYYY}") %>)</span>
          <% end %>
        </p>

        <div class="ml-auto flex flex-row space-x-2 ">
          <%= if @show_admin_controls do %>
            <button class={"#{button_class("primary")} px-2"} phx-click="edit" phx-target={@myself}>
              <%= svg_image("icon-edit-pencil", class: "w-5 h-5") %>
            </button>
            <button class={"#{button_class("danger")} px-2"} phx-click="delete" phx-target={@myself}>
              <%= svg_image("icon-trash", class: "w-5 h-5") %>
            </button>
          <% end %>

          <button class="mx-2" phx-click="toggle-description" phx-target={@myself}>
            <%= svg_image("chevron-down", class: "w-5 h-5 #{icon_rotation(@show_description)}") %>
          </button>
        </div>
      </div>

      <%= if @show_description do %>
        <pre class="whitespace-pre-line"><%= @notice.description %></pre>
      <% end %>
    </div>
    """
  end

  defp icon_rotation(true), do: ""
  defp icon_rotation(false), do: "rotate-180"
end
