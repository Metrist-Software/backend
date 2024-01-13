defmodule BackendWeb.Admin.Utilities.MonitorUsageLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Monitor Usage",
        monitor: nil,
        monitors: [],
        accounts_with_monitor: [],
        accounts_with_subscription: []
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(
        monitors: Backend.Projections.list_monitors(Domain.Helpers.shared_account_id)
      )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Monitor Usage</h2>

        <form phx-submit="submit" phx-change="change">
          <label for="monitor" class="form-label">
            Monitor
          </label>
          <select id="monitor" name="monitor" required>
            <%= options_for_select(BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false), @monitor) %>
          </select>

          <button type="submit" class={"#{button_class()} mt-3"}phx-disable-with="Loading...">
            Get Usage
          </button>
        </form>

        <hr class="my-5" />

        <h3 class="mb-3 text-xl">Accounts with Monitor Added</h3>

        <ul class="ml-5">
          <%= for account <- @accounts_with_monitor do %>
            <li class="mb-3">
              <.link navigate={"#{Routes.accounts_path(@socket, :index)}##{account.id}"} class="link">
                <%= Backend.Projections.Account.get_account_name(account) %>
              </.link>
            </li>
          <% end %>
        </ul>

        <h3 class="mb-3 text-xl">Accounts Subscribed to Monitor</h3>

        <ul class="ml-5">
          <%= for account <- @accounts_with_subscription do %>
            <li class="mb-3">
              <.link navigate={"#{Routes.accounts_path(@socket, :index)}##{account.id}"} class="link">
                <%= Backend.Projections.Account.get_account_name(account) %>
              </.link>
            </li>
          <% end %>
        </ul>

      </div>
    """
  end

  @impl true
  def handle_event("change", %{"monitor" => monitor}, socket) do
    socket =
      socket
      |> assign(monitor: monitor)
    {:noreply, socket}
  end

  def handle_event("submit", %{"monitor" => monitor}, socket) do
    accounts = Backend.Projections.get_accounts_for_monitor(monitor)
    accounts_with_subscriptions = Backend.Projections.get_accounts_with_subscription_to_monitor(monitor)

    socket = socket
      |> assign(
        accounts_with_monitor: accounts,
        accounts_with_subscription: accounts_with_subscriptions
      )

    {:noreply, socket}
  end
end
