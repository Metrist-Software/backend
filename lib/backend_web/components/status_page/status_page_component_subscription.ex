defmodule BackendWeb.Components.StatusPage.StatusPageComponentSubscription do
  use Phoenix.Component
  use PetalComponents
  use Phoenix.HTML

  def render(assigns) do

    assigns =
      assigns
      |> assign(subscription_select_all: Enum.all?(assigns.component_enabled_state, fn {_component, enabled} -> enabled end))

    ~H"""
    <label for="select-all" class="cursor-pointer"><input type="checkbox" name="select-all" id="select-all" phx-click={"page-component-subscription-select-all"} phx-target={@phx_target} checked={@subscription_select_all} class="mb-5 mr-1" />Select all</label>
    <ul class="grid md:grid-cols-2 lg:grid-cols-3 gap-3">
      <%= for %{name: component_name, status_page_component_id: component_id} <- @subscription_component_states do %>
        <li data-cy="check-card">
          <.form :let={f}
            id={component_id}
            as={:toggle_component_subscription}
            phx-change={"page-component-subscription"}
            phx-target={@phx_target}>
            <%= hidden_input f, :component_id, value: component_id %>
            <div class="block box overflow-hidden px-3 py-3">
              <div class="h-full">
                <header class="flex flex-col">
                  <div data-cy="check-link" class="flex flex-row">
                    <div class="flex-grow">
                    <h4 class="text-normal font-bold">
                      <%= component_name %>
                    </h4>
                    </div>
                    <div class="mr-3">
                      <.form_field
                        type="switch"
                        form={f}
                        field={:page_component_subscription}
                        label=""
                        value={Map.get(@component_enabled_state, component_id)} />
                    </div>
                  </div>
                </header>
              </div>
            </div>
          </.form>
        </li>
      <% end %>
    </ul>
    """
  end
end
