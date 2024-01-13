defmodule BackendWeb.MonitorsData do
  use BackendWeb, :live_view

  require Logger

  alias Backend.Projections

  @impl true
  def mount(params, session, socket) do
    account_id = session["current_user"].account_id
    socket =
      socket
      |> assign(
        telemetry: [],
        errors: [],
        has_private_instances: false,
        selected_monitors: (if !params["monitor"], do: [], else: [params["monitor"]]),
        initially_selected_monitor: params["monitor"],
        update_action: "prepend",
        subscribed_monitors: [])

    socket = if connected?(socket) do
      assign(socket, monitor_filter_data: monitor_filter_data(account_id))
    else
      assign(socket, monitor_filter_data: [])
    end

    socket = reload_monitors(socket)

    #subscribe to monitor added/removed
    Backend.PubSub.subscribe(account_id)

    {:ok, socket, temporary_assigns: [telemetry: nil, errors: nil]}
  end

  @impl true
  def handle_info(m = %{event: %Domain.Monitor.Events.TelemetryAdded{}}, socket) do
    # We are subscribed only to the acccount's monitors so no need to do account_id checks here
    {:noreply,
     assign(socket,
       telemetry: [ m.event ],
       update_action: "prepend"
     )}
  end

  def handle_info(m = %{event: %Domain.Monitor.Events.ErrorAdded{}}, socket) do
    # We are subscribed only to the acccount's monitors so no need to do account_id checks here
    {:noreply,
     assign(socket,
       errors: [ m.event ],
       update_action: "prepend"
     )}
  end

  # Just reload if the customer adds/removes monitors
  def handle_info(_ = %{event: %Domain.Account.Events.MonitorAdded{}}, socket), do: {:noreply, reload_monitors(socket)}
  def handle_info(_ = %{event: %Domain.Account.Events.MonitorRemoved{}}, socket), do: {:noreply, reload_monitors(socket)}

  def handle_info({:list_group_parent_selected, _, children}, socket) do
    socket = socket
    |> assign(selected_monitors: Enum.map(children, & &1.id), update_action: "replace")
    |> reload_monitors()

    {:noreply, socket}
  end

  def handle_info({:list_group_child_selected, id}, socket) do
    socket = socket
    |> assign(selected_monitors: [id], update_action: "replace")
    |> reload_monitors()
    {:noreply, socket}
  end

  def handle_info(:list_group_select_cleared, socket) do
    socket = socket
    |> assign(selected_monitors: [], update_action: "replace")
    |> reload_monitors()
    {:noreply, socket}
  end

  # catch all for other events we're not interested in
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp monitor_filter_data(account_id) do
    Backend.Projections.Dbpa.MonitorTags.list_monitors_by_tag(account_id)
    |> Enum.group_by(
      fn {tag, _, _} -> tag end,
      fn {_, id, name} -> %{id: id, label: name} end)
    |> Enum.map(fn {tag, children} ->
      %{
        id: tag || "other",
        label: Backend.Projections.Dbpa.MonitorTags.tag_name(tag),
        children: children
      }
    end)
  end

  defp reload_monitors(socket) do
    account_id = socket.assigns.current_user.account_id
    monitors = Projections.list_monitors(account_id)
    has_private_instances = Backend.Projections.has_monitor_instances(account_id)

    subscribed_monitors = BackendWeb.Helpers.subscribe_to_monitors(
      socket.assigns.subscribed_monitors,
      monitors,
      account_id,
      socket.assigns.selected_monitors
    )

    socket
    |> assign(
      monitors: monitors,
      telemetry: [],
      subscribed_monitors: subscribed_monitors,
      has_private_instances: has_private_instances
    )
  end
end
