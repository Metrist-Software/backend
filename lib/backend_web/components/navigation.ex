defmodule BackendWeb.Components.Navigation do
  use BackendWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, free_trial_days_left: 0)}
  end

  @impl true
  def update(%{current_user: nil}, socket) do
    {:ok, assign(socket,
      current_user: nil,
      is_metrist_admin: false,
      is_new?: true,
      path: "",
      free_trial_days_left: 0)}
  end

  def update(assigns, socket) do
    {:ok,
      assign(socket,
      current_user: assigns.current_user,
      is_metrist_admin: assigns.current_user.is_metrist_admin,
      is_new?: is_nil(assigns.current_user.account_id),
      path: assigns.path)
      |> maybe_assign_free_trial_days_left()}
  end

  defp maybe_assign_free_trial_days_left(%{assigns: assigns} = socket)
       when not assigns.is_new? do
    account = Backend.Projections.get_account!(assigns.current_user.account_id)
    days_left = Domain.Account.free_trial_days_left(account.free_trial_end_time)
    assign(socket, free_trial_days_left: days_left)
  end
  defp maybe_assign_free_trial_days_left(socket), do: socket

  @impl true
  def render(assigns) do
    assigns = assigns
    |> assign(:base_items, base_items(assigns))
    |> assign(:additional_items, additional_items(assigns))

    ~H"""
    <nav x-data="{ open: false}" class="sm:flex items-stretch flex-grow px-5 sm:px-0 sm:pb-0 item-stretch bg-dark-shade text-white print:hidden">
      <div class="flex pr-5">
        <% # Hamburger Icon %>
        <button type="button" class="nav-item py-3 sm:hidden" aria-controls="mobile-menu" aria-expanded="false" @click="open = !open">
          <span class="sr-only">Open menu</span>

          <svg class="block h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>

        <% # Metrist Icon %>
        <div class="flex">
          <.link navigate={Routes.monitors_path(@socket, :index)} class="p-3">
            <%= svg_image("logo-combined-white", "brand") %>
          </.link>
        </div>
      </div>

      <% # Nav Items %>
      <ul class="sm:flex flex-col sm:flex-row items-stretch sm:space-x-5 mb-5 sm:mb-0" x-bind:class="open ? 'block' : 'hidden'">
        <%= @base_items %>
        <%= @additional_items %>
      </ul>

      <% # Trial %>
      <ul class="sm:flex items-center sm:mr-2 sm:ml-auto " x-bind:class="open ? 'block' : 'hidden'">
        <.free_trial_countdown
          days_left={@free_trial_days_left}
          billing_path={Routes.live_path(@socket, BackendWeb.BillingLive)}
          current_user={@current_user}
          />
      </ul>

      <% # Help and Profile %>
      <ul class="sm:flex flex-col sm:flex-row items-stretch pb-3 sm:pb-0"  x-bind:class="open ? 'block' : 'hidden'">
        <li class="block">
          <.live_component module={BackendWeb.Components.Download}
                id="download"
                current_user={@current_user}
                path={@path} />
        </li>
        <li class="block">
          <.live_component module={BackendWeb.Components.HelpMenu}
                id="feedback"
                current_user={@current_user}
                path={@path} />
        </li>
        <li class="block">
          <.live_component module={BackendWeb.Components.ProfileMenu}
                id="loginout"
                show_trial_badge?={@free_trial_days_left > 0}
                current_user={@current_user} />
        </li>
      </ul>
    </nav>
    """
  end

  defp free_trial_countdown(assigns) when assigns.days_left > 0 do
   ~H"""
    <%= if assigns.current_user.is_read_only do %>
      <li class="inline-block bg-white rounded-2xl mr-1">
        <div class="text-black px-2">
          Trial
        </div>
      </li>
      <li class="inline-block">
        <div class="font-bold">
          <%= @days_left %>&nbsp;<span>days left</span>
        </div>
      </li>
    <% else %>
      <li class="inline-block bg-white rounded-2xl mr-1">
        <.link navigate={@billing_path} class="text-black px-2">
          Trial
        </.link>
      </li>
      <li class="inline-block">
        <.link navigate={@billing_path} class="font-bold">
          <%= @days_left %>&nbsp;<span class="underline">days left</span>
        </.link>
      </li>
    <% end %>
   """
  end
  defp free_trial_countdown(assigns), do: ~H||

  def active_path_class(path, path), do: "nav-item-active"
  def active_path_class(_, _), do: ""

  def base_items(assigns = %{is_new?: false}) do
    ~H"""
    <li class="block">
      <%= with route <- Routes.monitors_path(@socket, :index) do %>
        <.link navigate={route} class={"nav-item #{active_path_class(route, @path)}"}>
        Dependencies
        </.link>
      <% end %>
    </li>
    <li class="block">
      <%= with route <- Routes.live_path(@socket, BackendWeb.MonitorAlertingLive) do %>
        <.link navigate={route} class={"nav-item #{active_path_class(route, @path)}"}>
        Alerting
        </.link>
      <% end %>

    </li>
    <li class="block">
      <%= with route <- Routes.live_path(@socket, BackendWeb.UsersLive) do %>
        <.link navigate={route} class={"nav-item #{active_path_class(route, @path)}"}>
          Users
        </.link>
      <% end %>
    </li>
    """
  end

  def base_items(_) do
    ""
  end

  def additional_items(assigns = %{is_metrist_admin: true}) do
    ~H"""
    <li class="block">
      <%= with route <- Routes.live_path(@socket, BackendWeb.Admin.MetricsLive) do %>
        <.link navigate={route} class={"nav-item #{active_path_class(route, @path)}"}>
          Metrics
        </.link>
      <% end %>
    </li>

    <li class="block">
      <%= with route <- Routes.accounts_path(@socket, :index) do %>
        <.link navigate={route} class={"nav-item #{active_path_class(route, @path)}"}>
          Accounts
        </.link>
      <% end %>
    </li>

    <li class="block">
      <%= with route <- Routes.live_path(@socket, BackendWeb.Admin.AdminLive) do %>
        <.link navigate={route} class={"nav-item #{active_path_class(route, @path)}"}>
          Admin
        </.link>
      <% end %>
    </li>

    <li class="block">
      <.link href="/live_dashboard" target="_blank" class="nav-item">OTP Dash</.link>
    </li>
    """
  end

  def additional_items(_) do
    ""
  end
end
