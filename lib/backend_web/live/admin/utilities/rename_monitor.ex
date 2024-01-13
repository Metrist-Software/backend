defmodule BackendWeb.Admin.Utilities.RenameMonitor do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Rename Monitor",
        accounts: Backend.Projections.list_accounts(preloads: [:original_user]) |> Enum.sort_by(& String.downcase(&1.name || &1.id)),
        monitors: nil,
        selected_account: nil
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Rename Monitor</h2>
        <p class="m-5">Monitor names are copied from SHARED when a monitor is added to an account.</p>

        <form phx-submit="rename_monitor">
        Account
          <select id="account" name="account" phx-click="select-account" required>
            <%= options_for_select([{"Please select an account", nil} | Enum.map(@accounts, fn acc -> {BackendWeb.Helpers.get_account_name_with_id(acc), acc.id} end)], @selected_account) %>
          </select>

          <%= if @selected_account do %>
            Monitor
            <select id="monitor" name="monitor" required>
              <%= options_for_select(BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false), get_selected_monitor(@monitors)) %>
            </select>

            Name
            <input type="text" name="name" />

            <button type="submit" class={"#{button_class()} mt-3"}phx-disable-with="Loading...">Rename</button>
          <% end %>
        </form>
      </div>
    """
  end

  defp get_selected_monitor([]), do: nil
  defp get_selected_monitor(monitors), do: List.first(monitors).logical_name

  @impl true
  def handle_event("select-account", %{"value" => "" }, socket), do: {:noreply, assign(socket, selected_account: nil)}
  def handle_event("select-account", %{"value" => account }, socket), do: {:noreply, assign(socket, selected_account: account, monitors: Backend.Projections.list_monitors(account))}

  def handle_event("rename_monitor", %{"name" => ""}, socket), do: {:noreply, socket |> clear_flash() |> put_flash(:error, "Must provide a new name")}
  def handle_event("rename_monitor", %{"account" => account, "monitor" => monitor, "name" => name}, socket) do
    cmd = %Domain.Monitor.Commands.ChangeName{
      id: Backend.Projections.construct_monitor_root_aggregate_id(account, monitor),
      name: name
    }
    BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)

    updated_monitors = Enum.map(socket.assigns.monitors, fn mon ->
      case mon.logical_name == monitor do
        true -> %Backend.Projections.Dbpa.Monitor{ mon | name: name }
        false -> mon
      end
    end)

    {
      :noreply,
      assign(
        socket,
        current_command: nil,
        monitors: updated_monitors
      )
      |> clear_flash()
      |> put_flash(:info, "Succesfully updated #{monitor} for account #{account}")
    }
  end
end
