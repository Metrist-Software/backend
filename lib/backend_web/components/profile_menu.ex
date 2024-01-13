defmodule BackendWeb.Components.ProfileMenu do
  use BackendWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, show_trial_badge?: false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(dark_mode: true)}
  end

  @impl true
  def render(assigns = %{current_user: nil}) do
    ~H"""
    <div id={"profile-menu-#{@id}"}></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-full nav-dropdown font-roboto font-medium" id={"profile-menu-#{@id}"}>
      <.dropdown class="w-full" menu_items_wrapper_class="w-full md:w-max">
        <:trigger_element>
          <div class="nav-item flex w-full">
            <div class="p-1 fill-current rounded-full">
              <%= svg_image("icon-profile") %>
            </div>
            <span class="ml-3 pr-5">Profile</span>
          </div>
        </:trigger_element>

        <div>
          <div class="text-sm text-muted whitespace-nowrap mb-3 px-4" role="menuitem">
            Hi, <%= @current_user.email %>!
          </div>
        </div>

        <.dropdown_menu_item link_type="live_redirect" to={Routes.live_path(@socket, BackendWeb.ProfileLive)}>
          View/edit profile
        </.dropdown_menu_item>

        <.dropdown_menu_item link_type="live_redirect" to={Routes.apps_slack_path(@socket, :start)}>
          Install App
        </.dropdown_menu_item>

        <%= if not @current_user.is_read_only do %>
          <.dropdown_menu_item link_type="live_redirect" to={Routes.live_path(@socket, BackendWeb.BillingLive)}>
            <span class="inline-block">Billing</span>
            <%= if @show_trial_badge? do %>
            <.badge color="gray" label="Trial" />
            <% end %>
          </.dropdown_menu_item>
        <% end %>

        <div class="px-4 text-sm space-y-2">
          <hr />

          <div class="text-muted">
            Theme
          </div>

          <div class="pl-3">
            <.live_component
              module={BackendWeb.Components.LightDarkModeToggle}
              id="toggle_light_dark_mode_2"
              :let={{parent, mode}}
            >
              <div class="space-y-2">
                <button
                  class={"#{dark_mode_button_class(mode == :dark)}"}
                  phx-click="push-toggle"
                  phx-target={parent}
                  disabled={mode == :dark}
                >
                  Dark mode
                </button>

                <button
                  class={"#{dark_mode_button_class(mode == :light)}"}
                  phx-click="push-toggle"
                  phx-target={parent}
                  disabled={mode == :light}
                >
                  Light mode
                </button>
              </div>
            </.live_component>
          </div>

          <hr />
        </div>

        <.dropdown_menu_item link_type="live_redirect" to={Routes.auth_path(BackendWeb.Endpoint, :delete)}>
          Sign out
        </.dropdown_menu_item>
      </.dropdown>
    </div>
    """
  end

  def dark_mode_button_class(true), do: "block text-muted cursor-default"
  def dark_mode_button_class(_), do: "block"
end
