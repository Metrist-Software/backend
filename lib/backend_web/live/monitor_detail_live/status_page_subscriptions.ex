defmodule BackendWeb.MonitorDetailLive.StatusPageSubscriptions do
  use BackendWeb, :live_component
  alias BackendWeb.Components.StatusPage.UI.PageComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
        enabled_subscription_component_states: [],
        show_all: false
      )
    }
  end

  @impl true
  def handle_event("start-configuring", _params, socket) do
    send(self(), :start_configuring)
    {:noreply, socket}
  end

  @impl true
  def update(%{subscription_component_states: subscription_component_states, show_all: show_all}=assigns, socket) do
    enabled_subscription_component_states =
      if show_all do
        subscription_component_states
      else
        Enum.filter(subscription_component_states, fn %{enabled: enabled} -> enabled end)
      end
    {:ok,
      socket
      |> assign(assigns)
      |> assign(enabled_subscription_component_states: enabled_subscription_component_states)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="font-lato mt-3" id={@id}>
      <header class="flex flex-col md:flex-row">
        <div class="flex flex-col mb-3 lg:mb-0">
          <h2 class="mb-2 font-bold">
            Vendor status page components
          </h2>
        </div>
      </header>
      <%= if length(@enabled_subscription_component_states) > 0 do %>
        <.render_list enabled_subscription_component_states={@enabled_subscription_component_states} />
      <% else %>
        <div class="alert alert-info my-3">
          No subscriptions found.
          <%= if (not is_nil(@current_user)) && (not @current_user.is_read_only) do %>
            <a phx-click="start-configuring" href="#" phx-target={@myself} class="underline">Configure</a> to subscribe to a status page component
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_list(assigns) do
    ~H"""
    <div class="flex flex-wrap">
      <%= for %{name: component_name, state: state} <- @enabled_subscription_component_states do %>
        <div class="flex-col md:flex-row md:w-1/3">
          <div class={"flex flex-row my-0.5 items-center #{if state == :down, do: "bg-red-100 rounded text-red-900 font-bold"}"}>
            <div class="flex flex-col pl-2 py-2">
              <svg class={"#{PageComponent.class(%{type: :spinner, state: state})} h-4 w-4"} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="3"></circle>
              </svg>
            </div>
            <div class="spark flex-1 ml-2 mr-2">
              <%= component_name %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
