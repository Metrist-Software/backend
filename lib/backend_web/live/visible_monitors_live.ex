defmodule BackendWeb.Admin.VisibleMonitorsLive do
  use BackendWeb, :live_view

  @impl true
  def mount(%{"account_id" => account_id}, _session, socket) do
    grouped_monitors =
      Backend.Projections.list_monitors(nil, [:monitor_tags])
      |> Enum.sort_by(& &1.logical_name)
      |> Enum.group_by(&(tag_label(&1.monitor_tags)))

    account = Backend.Projections.get_account(account_id, [:original_user])

    selected_monitors =
      Backend.Projections.Dbpa.VisibleMonitor.visible_monitor_logical_names(account_id)

    socket =
      socket
      |> assign(
        account: account,
        grouped_monitors: grouped_monitors,
        selected_monitors: selected_monitors,
        page_title: "Edit visible monitors"
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ml-3">
        <h3 class="text-2xl my-5">Edit visible monitors for "<%= Backend.Projections.Account.get_account_name(@account) %>" (<%= @account.id %>)</h3>

        <ul>
        <%= for {tag, monitors} <- @grouped_monitors do %>
          <h4 class="text-xl my-2"><%= tag %></h4>
          <%= for monitor <- monitors do %>

            <li>
            <input
                type="checkbox"
                checked={selected?(monitor, @selected_monitors)}
                phx-click="toggle-monitor"
                phx-value-logical-name={monitor.logical_name}
            />
            <%= monitor.name %> (<%= monitor.logical_name %>)
            </li>
          <% end %>
        <% end %>
        </ul>

        <button
          class={"mt-5 #{button_class()}"}
          type="submit"
          phx-click="save"
          phx-disable-with="Saving..."
        >
          Save
        </button>
    </div>
    """
  end

  @impl true
  def handle_event("toggle-monitor", %{"logical-name" => monitor_logical_name}, socket) do
    selected_monitors = socket.assigns.selected_monitors

    selected_monitors =
      if monitor_logical_name in selected_monitors do
        IO.puts("Unselecting #{monitor_logical_name}")
        List.delete(selected_monitors, monitor_logical_name)
      else
        IO.puts("Selecting #{monitor_logical_name}")
        [monitor_logical_name | selected_monitors]
      end

    {:noreply, assign(socket, selected_monitors: selected_monitors)}
  end

  def handle_event("save", _params, socket) do
    cmd = %Domain.Account.Commands.SetVisibleMonitors{
      id: socket.assigns.account.id,
      monitor_logical_names: socket.assigns.selected_monitors
    }

    BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)
    {:noreply, socket}
  end

  defp selected?(monitor, selected_monitors), do: monitor.logical_name in selected_monitors

  # Pretty much all our tags are going to be the first or second cases.
  defp tag_label(nil), do: "Other"
  defp tag_label(%Backend.Projections.Dbpa.MonitorTags{tags: t}), do: tag_label(t)
  defp tag_label([t]), do: tag_label(t)
  defp tag_label(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
  defp tag_label(other), do: inspect(other)
end
