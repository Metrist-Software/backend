defmodule BackendWeb.Components.Monitor.MonitorConfigureCheck do
  use BackendWeb, :live_component
  require Logger

  alias Backend.Projections.Dbpa.CheckConfig

  @impl true
  def mount(socket) do
    socket = assign(socket,
      check_logical_name: nil,
      check_name: nil,
      monitor: nil,
      snapshot: nil,
      telemetry: nil,
      instances: [],
      custom_thresholds_enabled: false,
      show_values: false,
      enabled: false,
      check_config: nil,
      errors: %{}
    )
    {:ok, socket}
  end

  @impl true
  def update(%{refresh: true} = assigns, socket) do
    {:ok,
    socket
    |> assign(assigns)
    }
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
    socket
    |> assign(assigns)
    |> assign_proper_instances()
    |> assign_check_config()
    |> assign_custom_thresholds_enabled()
    }
  end

  defp handle_threshold_change(threshold_value, threshold, socket, additional_message \\ "") do
    socket = case BackendWeb.MonitorDetailLiveConfigure.try_threshold_parse(threshold_value, socket.assigns.check_config, threshold) do
      { :invalid, value, msg } ->
        updated_check_config =
          Map.put(socket.assigns.check_config,
          threshold,
          value)

        socket
        |> assign(check_config: updated_check_config)
        |> assign(errors: Map.put(socket.assigns.errors, threshold, "#{msg} #{additional_message}"))
        |> send_error_update()
      { :ok, floatValue} ->
        updated_check_config =
          Map.put(socket.assigns.check_config,
          threshold,
          BackendWeb.MonitorDetailLiveConfigure.get_translated_threshold_value(floatValue, threshold))

        socket
        |> assign( check_config: updated_check_config)
        |> assign(errors: Map.delete(socket.assigns.errors, threshold))
        |> send_check_update(updated_check_config)
      end
      socket
  end

  defp send_check_update(socket, check_config) do
    send(self(), {:configure_check_updated, %{ check_logical_name: socket.assigns.check_logical_name, updated_check_config: CheckConfig.to_csharp_map(check_config), errors: socket.assigns.errors } })
    socket
  end

  defp send_error_update(socket) do
    send(self(), {:configure_check_errors_updated, %{ check_logical_name: socket.assigns.check_logical_name, errors: socket.assigns.errors } })
    socket
  end

  @impl true
  def handle_event("handle-form-change", %{"_target" => ["degraded_threshold"], "degraded_threshold" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :degraded_threshold, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["degraded_down_count"], "degraded_down_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :degraded_down_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["degraded_up_count"], "degraded_up_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :degraded_up_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["error_down_count"], "error_down_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :error_down_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["error_up_count"], "error_up_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :error_up_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["degraded_timeout"], "degraded_timeout" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :degraded_timeout, socket, "Must be smaller than or equal to the down timeout.")}
  end

  def handle_event("handle-form-change", %{"_target" => ["error_timeout"], "error_timeout" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :error_timeout, socket, "Must be greater than or equal to the degraded timeout")}
  end

  def handle_event("handle-form-change", %{"_target" => ["enabled"], "enabled" => "on"}, socket) do
    send_check_update(socket, CheckConfig.get_empty(socket.assigns.check_logical_name))
    {:noreply, assign(socket, enabled: true)}
  end

  def handle_event("handle-form-change", %{"_target" => ["enabled"]}, socket) do
    send_check_update(socket, nil)
    {:noreply, assign(socket,
      enabled: false,
      custom_thresholds_enabled: false,
      show_values: false)}
  end

  def handle_event("handle-form-change", %{"_target" => ["custom_thresholds_enabled"], "custom_thresholds_enabled" => "on"}, socket) do
    check_config_with_defaults = CheckConfig.get_defaults(socket.assigns.analyzer_config, socket.assigns.check_logical_name)
    send_check_update(socket, check_config_with_defaults)
    {:noreply, assign(socket, custom_thresholds_enabled: true, check_config: check_config_with_defaults)}
  end

  def handle_event("handle-form-change", %{"_target" => ["custom_thresholds_enabled"]}, socket) do
    send_check_update(socket, CheckConfig.get_empty(socket.assigns.check_logical_name))
    {:noreply, assign(socket, custom_thresholds_enabled: false)}
  end

  def handle_event("show-values", _params, socket) do
    {:noreply, assign(socket, show_values: true)}
  end

  def handle_event("hide-values", _params, socket) do
    {:noreply, assign(socket, show_values: false)}
  end

  defp assign_custom_thresholds_enabled(%{assigns: %{check_config: check_config}} = socket) when is_nil(check_config) do
    socket
    |> assign(:custom_thresholds_enabled, false)
  end

  defp assign_custom_thresholds_enabled(%{assigns: %{check_config: check_config}} = socket) do
    socket
    |> assign(:custom_thresholds_enabled, check_config.degraded_threshold != nil)
  end

  defp assign_proper_instances(%{assigns: %{instances: instances}} = socket) do
    socket
    |> assign(:instances, instances)
  end

  defp assign_check_config(%{assigns: %{analyzer_config: analyzer_config, check_logical_name: check_logical_name}} = socket) do
    check_config =
      analyzer_config.check_configs
      |> Enum.find(fn cd -> Map.get(cd, "CheckId") == check_logical_name end)

    case check_config do
      nil ->
        socket
        |> assign(check_config: nil, enabled: false)
      _ ->
        socket
        |> assign(check_config: CheckConfig.from_csharp_map(check_config, analyzer_config), enabled: true)
    end
  end

  @impl true
  # we will have multiple of these on a page so preload data all at once
  def preload(list_of_assigns) do
    first_data = Enum.at(list_of_assigns, 0, nil)

    shared_snapshot = case Backend.RealTimeAnalytics.get_snapshot(Domain.Helpers.shared_account_id, first_data.monitor.logical_name) do
      {:ok, shared_snapshot} -> shared_snapshot
      _ -> nil
    end

    # load all telemetry for 8 hours for both shared and account telemetry
    from_time = DateTime.add(DateTime.utc_now(), :timer.hours(8) * -1, :millisecond)
    shared_aggregate_telemetry = Backend.Telemetry.get_aggregate_telemetry(from_time, "10 minutes", first_data.monitor.logical_name, :p50, group_by_instance: true)
    aggregate_telemetry = Backend.Telemetry.get_aggregate_telemetry(from_time, "10 minutes", first_data.monitor.logical_name, :p50, group_by_instance: true, account_id: first_data.current_user.account_id)
    telemetry = aggregate_telemetry ++ shared_aggregate_telemetry
    Enum.map(list_of_assigns, fn assigns ->
      assigns
      |> Map.put(:telemetry, Enum.filter(telemetry, &(&1.check_id == assigns.check_logical_name)))
      |> Map.put(:shared_snapshot, shared_snapshot)
    end)
  end
end
