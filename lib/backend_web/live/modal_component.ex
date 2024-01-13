defmodule BackendWeb.ModalComponent do
  use BackendWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="modal"
      phx-capture-click="close"
      phx-window-keydown="close"
      phx-key="escape"
      phx-target={"##{@id}"}
      phx-page-loading>

      <div class="modal-content">
        <%= live_patch raw("&times;"), to: @return_to, class: "modal-close" %>
        <%= live_component @component, @opts %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
