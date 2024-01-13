defmodule BackendWeb.Components.HelpMenu do
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
     |> assign(
       modal_visible: false,
       thankyou_visible: false
     )}
  end

  # For now, we only render when logged in
  @impl true
  def render(assigns = %{current_user: nil}) do
    ~H"""
    <div id={"help-menu-#{@id}"}></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="nav-dropdown" id={"help-menu-#{@id}"}>
      <.dropdown class="w-full" menu_items_wrapper_class="w-full md:w-max">
        <:trigger_element>
          <div class="nav-item flex w-full">
            <div class="p-1 fill-current rounded-full">
              <%= svg_image("icon-info-fill") %>
            </div>
            <span class="ml-3 pr-5">Help</span>
          </div>
        </:trigger_element>

        <.dropdown_menu_item link_type="a" to="https://docs.metrist.io">
          <%= svg_image("icon-book", class: "mr-3 inline w-5 h-5 fill-current") %> Docs
        </.dropdown_menu_item>

        <.dropdown_menu_item link_type="a" to="mailto:support@metrist.io">
          <%= svg_image("icon-envelope", class: "mr-3 inline w-5 h-5 fill-current") %> Contact Support
        </.dropdown_menu_item>

        <.dropdown_menu_item phx-click="modal-open" phx-target={@myself}>
          <%= svg_image("icon-feedback", class: "mr-3 inline w-5 h-5 fill-current") %> Feedback
        </.dropdown_menu_item>
      </.dropdown>

      <%= feedback_modal(assigns) %>
    </div>
    """
  end

  def feedback_modal(assigns = %{modal_visible: true}) do
    ~H"""
    <.modal max_width="xl" title="We love hearing from you!" close_modal_target={@myself} class="text-gray-800 dark:text-gray-200">
      <%= unless @thankyou_visible do %>
        <form id="feedback" phx-submit="modal-submit" phx-target={@myself} >
          <p>
            Please submit feedback using the form below. If you need to reach support,
            email <a href="mailto:support@metrist.io" class="link">support@metrist.io</a>.
          </p>

          <textarea required rows="8" name="feedback" class="my-1"></textarea>
          <input type="hidden" name="ua" id="ua" phx-hook="SetUa"/>

          <div class="flex justify-end gap-x-3">
            <button type="button" phx-click={PetalComponents.Modal.hide_modal(@myself)} class="btn btn-outline">
              Cancel
            </button>
            <input type="submit" value="Submit" class="btn btn-green"/>
          </div>
        </form>
      <% else %>
        <div class="modal-body relative">
          <p>
            Thank you for the time you took to give us feedback.
          </p>
          <p class="mt-2">
            If you have any issues using Metrist, please do not hesitate to contact
            our support via email to <a href="mailto:support@metrist.io" class="link">support@metrist.io</a>.
          </p>
          <button type="button" phx-click={PetalComponents.Modal.hide_modal(@myself)} class="btn btn-outline my-4">
            Close
          </button>
        </div>
      <% end %>
    </.modal>
    """
  end

  def feedback_modal(assigns) do
    ~H"""
    <div></div>
    """
  end

  @impl true
  def handle_event("modal-open", _params, socket) do
    {:noreply,
     assign(socket,
       modal_visible: true,
       thankyou_visible: false
     )}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, modal_visible: false)}
  end

  def handle_event("modal-submit", params, socket) do
    Backend.Integrations.Feedback.submit_feedback(
      socket.assigns.current_user,
      params["ua"],
      socket.assigns.path,
      params["feedback"]
    )

    {:noreply,
     assign(socket,
       thankyou_visible: true
     )}
  end
end
