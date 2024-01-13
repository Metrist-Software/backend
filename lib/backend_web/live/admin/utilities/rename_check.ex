defmodule BackendWeb.Admin.Utilities.RenameCheck do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Rename Check (SHARED)",
        monitors: Backend.Projections.list_monitors("SHARED"),
        checks: nil,
        selected_monitor: nil
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Rename Check</h2>
        <p class="m-5">This renames the SHARED check. Check names come from SHARED except for private telemetry</p>

        <form phx-submit="rename_check">
          Monitor
          <select id="monitor" name="monitor" phx-click="select-monitor" required>
            <%= options_for_select([{"Please choose a monitor", nil} | BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false)], @selected_monitor) %>
          </select>

          <%= if @selected_monitor do %>
            <%= if length(@checks) > 0 do %>
            Check
            <select id="check" name="check" required>
              <%= options_for_select(Enum.map(@checks, fn c -> { c.name || c.logical_name, c.logical_name } end), get_selected_check(@checks)) %>
            </select>

            Name
            <input type="text" name="name" />

            <button type="submit" class={"#{button_class()} mt-3"}phx-disable-with="Loading...">Rename</button>
            <% else %>
              No checks found.
            <% end %>
          <% end %>
        </form>
      </div>
    """
  end

  defp get_selected_check([]), do: nil
  defp get_selected_check(checks), do: List.first(checks).logical_name

  @impl true
  def handle_event("select-monitor", %{"value" => "" }, socket), do: {:noreply, assign(socket, selected_monitor: nil)}
  def handle_event("select-monitor", %{"value" => monitor }, socket) do
    {
      :noreply,
      assign(socket,
        selected_monitor: monitor,
        checks: Backend.Projections.get_checks("SHARED", monitor) |> Enum.sort_by(&(&1.name))
      )
    }
  end

  def handle_event("rename_check", %{"name" => ""}, socket), do: {:noreply, socket |> clear_flash() |> put_flash(:error, "Must provide a new name")}
  def handle_event("rename_check", %{"check" => check_logical_name, "monitor" => monitor_logical_name, "name" => name}, socket) do
    cmd = %Domain.Monitor.Commands.UpdateCheckName{
      id: Backend.Projections.construct_monitor_root_aggregate_id("SHARED", monitor_logical_name),
      logical_name: check_logical_name,
      name: name
    }

    BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)

    updated_checks = Enum.map(socket.assigns.checks, fn c ->
      case c.logical_name == check_logical_name do
        true -> %Backend.Projections.Dbpa.MonitorCheck{ c | name: name }
        false -> c
      end
    end)

    {
      :noreply,
      assign(
        socket,
        checks: updated_checks
      )
      |> clear_flash()
      |> put_flash(:info, "Succesfully updated #{check_logical_name} on #{monitor_logical_name} for SHARED")
    }
  end
end
