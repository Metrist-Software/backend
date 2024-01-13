defmodule BackendWeb.Admin.Utilities.BulkMonitorOperations do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Bulk Monitor Operations",
        operation: nil,
        monitor: nil,
        monitors: [],
        accounts: []
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(
        monitors: Backend.Projections.list_monitors(Domain.Helpers.shared_account_id),
        accounts: Backend.Projections.list_accounts(preloads: [:original_user]) |> Enum.sort_by(& String.downcase(&1.name || &1.id)),
        select_all: false,
        selected_accounts: []
      )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Bulk Monitor Operations</h2>
        <p class="m-5">Perform monitor operations on multiple accounts simultaneously.<br />Note: add-visible monitor and remove-visible-monitor will do nothing if the account has "all" monitors as an empty array as that is a special case</p>

        <form phx-submit="submit">
          <label for="monitor" class="form-label">
            Monitor
          </label>
          <select id="monitor" name="monitor" required phx-update="ignore">
            <%= options_for_select([ {"Please choose a monitor", nil} | BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false)], @monitor) %>
          </select>

          <label for="operation" class="form-label">
            Operation
          </label>
          <select id="operation" name="operation" required phx-update="ignore">
            <%= options_for_select(
              [
                {"Add Visible Monitor", "add-visible-monitor"},
                {"Remove Visible Monitor", "remove-visible-monitor"},
                {"Add Monitor", "add-monitor"},
                {"Remove Monitor", "remove-monitor"}
              ], @operation || "add-visible-monitor") %>
          </select>

          <div class="mt-5 mb-2">Accounts to apply operation to:</div>
          <div class="mr-5"><label for="select-all" class="cursor-pointer"><input type="checkbox" name="select-all" id="select-all" phx-click="select-all" checked={@select_all} class="mr-2" />Select All</label></div>
          <div class="grid grid-cols-1 md:grid-cols-3">
          <%= for acc <- @accounts do %>
            <div><label for={"account_#{acc.id}"} class="cursor-pointer"><input type="checkbox" name="accounts[]" value={acc.id} id={"account_#{acc.id}"} phx-value-account-id={acc.id} phx-click="toggle-account" checked={is_checked?(acc.id, @selected_accounts)} class="mr-2" /><%= BackendWeb.Helpers.get_account_name_with_id(acc) %></label></div>
          <% end %>
          </div>

          <button type="submit" class={"#{button_class()} mt-3"}phx-disable-with="Loading...">
            Assign
          </button>
        </form>
      </div>
    """
  end

  defp is_checked?(account_id, selected_accounts) do
    selected_accounts
    |> Enum.member?(account_id)
  end

  def handle_event("select-all", %{"value" => "on"}, socket) do
    {
      :noreply,
      assign(socket,
        selected_accounts: Enum.map(socket.assigns.accounts, &(&1.id)),
        select_all: true
      )
    }
  end

  def handle_event("select-all", %{}, socket) do
    {
      :noreply,
      assign(socket,
        selected_accounts: [],
        select_all: false
      )
    }
  end

  def handle_event("toggle-account", %{"account-id" => account_id}, socket) do
    new_selected_list = if account_id in socket.assigns.selected_accounts do
      List.delete(socket.assigns.selected_accounts, account_id)
    else
      [account_id | socket.assigns.selected_accounts]
    end
    {
      :noreply,
      assign(socket,
        selected_accounts: new_selected_list,
        select_all: length(new_selected_list) == length(socket.assigns.accounts)
      )
    }
  end

  @impl true
  def handle_event("submit", %{"monitor" => monitor, "accounts" => accounts, "operation" => operation}, socket) do
    build_and_send_commands(
      monitor,
      accounts,
      operation,
      socket
      )
  end

  def handle_event("submit", %{"monitor" => _monitor}, socket) do
    {:noreply,
    socket
    |> clear_flash()
    |> put_flash(:error, "Please select at least one account.")
    }
  end


  defp get_operation_transform_function("add-visible-monitor", _socket) do
    fn monitor, account ->
      %Domain.Account.Commands.AddVisibleMonitor{
        id: account,
        monitor_logical_name: monitor
      }
    end
  end

  defp get_operation_transform_function("remove-visible-monitor", _socket) do
    fn monitor, account ->
      %Domain.Account.Commands.RemoveVisibleMonitor{
        id: account,
        monitor_logical_name: monitor
      }
    end
  end

  defp get_operation_transform_function("add-monitor", socket) do
    fn monitor, account ->
      monitor_name = Enum.find(socket.assigns.monitors, &(&1.logical_name == monitor)).name

      %Domain.Account.Commands.ChooseMonitors{
        id: account,
        user_id: socket.assigns.current_user.id,
        add_monitors: [
          %{
            logical_name: monitor,
            name: monitor_name,
            default_degraded_threshold: 5.0,
            instances: [],
            check_configs: []
          }
        ],
        remove_monitors: []
      }
    end
  end

  defp get_operation_transform_function("remove-monitor", socket) do
    fn monitor, account ->
      %Domain.Account.Commands.ChooseMonitors{
        id: account,
        user_id: socket.assigns.current_user.id,
        add_monitors: [],
        remove_monitors: [monitor]
      }
    end
  end

  defp build_and_send_commands(monitor, accounts, operation, socket) do
    cmds = accounts
    |> Enum.map(&(get_operation_transform_function(operation, socket).(monitor, &1)))

    for cmd <- cmds do
      Logger.info("Dispatching #{inspect cmd}")
      BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)
    end

    {:noreply,
      assign(socket,
      select_all: false,
      selected_accounts: [])
      |> clear_flash()
      |> put_flash(:info, "Operation complete.")
    }
  end
end
