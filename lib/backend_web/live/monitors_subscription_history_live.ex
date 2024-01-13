defmodule BackendWeb.MonitorsSubscriptionHistoryLive do
  use BackendWeb, :live_view

  require Logger

  alias Backend.Projections

  @hours_lookback 24

  @impl true
  def mount(params, session, socket) do
    account_id = session["current_user"].account_id
    monitor_logical_name = params["monitor"]
    monitors = Projections.list_monitors(account_id)

    socket =
      socket
      |> assign(
        hours_lookback: @hours_lookback,
        page_title: (if !monitor_logical_name, do: "Subscription History", else: "Subscription History - #{monitor_logical_name}"),
        selected_monitors: (if !monitor_logical_name, do: [], else: [monitor_logical_name]),
        initially_selected_monitor: monitor_logical_name,
        update_action: "prepend",
        num_deliveries: 0,
        monitors: monitors
        )

    socket = if connected?(socket) do
      assign(socket, monitor_filter_data: monitor_filter_data(account_id))
    else
      assign(socket, monitor_filter_data: [])
    end

    socket = reload_deliveries(socket)

    # Subscribe to account id
    Backend.PubSub.subscribe("Account:#{account_id}")

    {:ok, socket, temporary_assigns: [subscription_deliveries: nil]}
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

  defp reload_deliveries(socket) do
    account_id = socket.assigns.current_user.account_id

    subscription_deliveries = Projections.subscription_deliveries_since(account_id, socket.assigns.selected_monitors, @hours_lookback, [:alert, :subscription, :monitor])
    socket
    |> assign(
      subscription_deliveries: subscription_deliveries,
      num_deliveries: Enum.count(subscription_deliveries)
    )
  end

  @impl true
  def handle_info(m = %{event: %Domain.Account.Events.SubscriptionDeliveryAdded{}}, socket) do
    {
      :noreply,
      socket
        |>  maybe_add_delivery(m.event.subscription_delivery_id, m.event.monitor_logical_name)
    }
  end

  def handle_info(m = %{event: %Domain.Account.Events.SubscriptionDeliveryAddedV2{}}, socket) do
    alert = Backend.Projections.get_alert_by_id(m.event.id, m.event.alert_id)
    {
      :noreply,
      socket
        |>  maybe_add_delivery(m.event.subscription_delivery_id, alert.monitor_logical_name)
    }
  end

  def handle_info({:list_group_parent_selected, _, children}, socket) do
    socket = socket
    |> assign(selected_monitors: Enum.map(children, & &1.id), update_action: "replace")
    |> reload_deliveries()

    {:noreply, socket}
  end

  def handle_info({:list_group_child_selected, id}, socket) do
    socket = socket
    |> assign(selected_monitors: [id], update_action: "replace")
    |> reload_deliveries()
    {:noreply, socket}
  end

  def handle_info(:list_group_select_cleared, socket) do
    socket = socket
    |> assign(selected_monitors: [], update_action: "replace")
    |> reload_deliveries()
    {:noreply, socket}
  end

  # catch all for other events we're not interested in
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp get_red_if_required(status_code) when is_nil(status_code), do: ""
  defp get_red_if_required(status_code) do
    isErrorCode = to_string(status_code)
    |> String.starts_with?("5")

    if isErrorCode, do: "text-red-900", else: "text-muted"
  end

  defp render_method("slack"), do: render_icon("slack-icon", "Slack")
  defp render_method("teams"), do: render_icon("ms-teams-icon", "Teams")
  defp render_method("datadog"), do: render_icon("datadog-icon", "Datadog")
  defp render_method(other), do: other

  defp render_icon(icon, label) do
    {:safe, html} = svg_image(icon, class: "w-5 h-5 pr-1 inline")
    {:safe, html <> label}
  end

  defp maybe_add_delivery(socket, subscription_delivery_id, monitor_logical_name) do
    selected_monitors = socket.assigns.selected_monitors

    if Enum.empty?(selected_monitors) or (monitor_logical_name in selected_monitors) do
      new_delivery = Projections.get_subscription_delivery(account_id(socket), subscription_delivery_id, [:alert, :subscription, :monitor])

      assign(socket,
            subscription_deliveries: [ new_delivery ],
            num_deliveries: socket.assigns.num_deliveries + 1,
            update_action: "prepend")
    else
      socket
    end
  end
end
