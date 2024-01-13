defmodule BackendWeb.MonitorDetailLiveConfigure do
  use BackendWeb, :live_component

  require Logger

  alias BackendWeb.MonitorDetailLive
  alias Backend.Projections.Dbpa.AnalyzerConfig
  alias Backend.Projections.Dbpa.CheckConfig
  alias Domain.StatusPage.Commands, as: StatusPageCmds
  alias BackendWeb.Helpers

  @default_check_timeout 900000

  @impl true
  def mount(socket) do
    socket = assign(socket,
      errors: %{},
      check_errors: %{}
    )

    {
      :ok,
      socket
    }
  end

  @impl true
  def update(%{check_logical_name: check_logical_name, updated_check_config: updated_check_config, errors: errors}, socket) when is_nil(updated_check_config) do
    Logger.info("Removing check config")
        new_analyzer_config =
          socket.assigns.analyzer_config
          |> remove_check_config(check_logical_name)

        #received through live_view send_update when a check has been changed as
        # we don't want to store the master analyzer_config yet on the liveview
        {:ok, socket
              |> assign(analyzer_config: new_analyzer_config)
              |> assign_check_errors(check_logical_name, errors)}
  end

  @impl true
  def update(%{check_logical_name: check_logical_name, updated_check_config: updated_check_config, errors: errors}, socket) do
    #received through live_view send_update when a check has been changed as
    # we don't want to store the master analyzer_config yet on the liveview
    {:ok, socket
          |> assign(analyzer_config: socket.assigns.analyzer_config |> update_check_config(check_logical_name, updated_check_config))
          |> assign_check_errors(check_logical_name, errors)
          }
  end

  @impl true
  def update(%{check_logical_name: check_logical_name, errors: errors}, socket) do
    #received through live_view send_update when a check has been changed as
    # we don't want to store the master analyzer_config yet on the liveview
    {:ok, socket
          |> assign_check_errors(check_logical_name, errors)
          }
  end

  @impl true
  def update(%{monitor: monitor, snapshot: snapshot, analyzer_config: analyzer_config, current_user: current_user} = assigns, socket) do
    component_enabled_state =
      assigns.subscription_component_states
        |> Enum.reduce(%{}, fn %{enabled: enabled, status_page_component_id: status_page_component_id}, acc ->
          Map.put(acc, status_page_component_id, enabled)
        end)

    socket = socket
    |> assign(assigns)
    |> assign(component_enabled_state: component_enabled_state)
    |> MonitorDetailLive.load_instances_and_checks(current_user.account_id, monitor.logical_name, analyzer_config, snapshot)
    |> prepare_analyzer_config()
    {:ok, socket}
  end

  @impl true
  def handle_event("add-instance", %{"instance" => region}, socket) do
    new_analyzer_config = Map.put(socket.assigns.analyzer_config, :instances, [region | socket.assigns.analyzer_config.instances])
    socket = socket
    |> assign(
      analyzer_config: new_analyzer_config,
      active_instances: Enum.sort([ region | socket.assigns.active_instances])
      )
    {:noreply, socket}
  end

  def handle_event("remove-instance", %{"instance" => region}, socket) do
    new_analyzer_config = Map.put(socket.assigns.analyzer_config, :instances, Enum.reject(socket.assigns.analyzer_config.instances, fn item -> item == region end))
    socket = socket
    |> assign(
      analyzer_config: new_analyzer_config,
      active_instances: Enum.sort(Enum.reject(socket.assigns.active_instances, fn item -> item == region end))
      )
    {:noreply, socket}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_degraded_threshold"], "default_degraded_threshold" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_degraded_threshold, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_degraded_down_count"], "default_degraded_down_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_degraded_down_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_degraded_up_count"], "default_degraded_up_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_degraded_up_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_error_down_count"], "default_error_down_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_error_down_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_error_up_count"], "default_error_up_count" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_error_up_count, socket)}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_degraded_timeout"], "default_degraded_timeout" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_degraded_timeout, socket, "Must be smaller than or equal to the down timeout.")}
  end

  def handle_event("handle-form-change", %{"_target" => ["default_error_timeout"], "default_error_timeout" => threshold_value}, socket) do
    {:noreply, handle_threshold_change(threshold_value, :default_error_timeout, socket, "Must be greater than or equal to the degraded timeout")}
  end

  def handle_event("cancel-configuration", _target, socket) do
    send(self(), {:stop_configuring, nil, nil})
    {:noreply, socket}
  end

  def handle_event("save-configuration", _target, socket) do
    account_id = socket.assigns.current_user.account_id
    monitor_logical_name = socket.assigns.monitor.logical_name
    cmd = %Domain.Monitor.Commands.UpdateAnalyzerConfig{
      id: Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor_logical_name),
      default_degraded_threshold: socket.assigns.analyzer_config.default_degraded_threshold,
      default_degraded_down_count: socket.assigns.analyzer_config.default_degraded_down_count,
      default_degraded_up_count: socket.assigns.analyzer_config.default_degraded_up_count,
      default_error_down_count: socket.assigns.analyzer_config.default_error_down_count,
      default_error_up_count: socket.assigns.analyzer_config.default_error_up_count,
      default_degraded_timeout: socket.assigns.analyzer_config.default_degraded_timeout,
      default_error_timeout: socket.assigns.analyzer_config.default_error_timeout,
      instances: socket.assigns.analyzer_config.instances,
      check_configs: socket.assigns.analyzer_config.check_configs
    }

    status_page = Backend.Projections.Dbpa.StatusPage.status_page_by_name(
      Domain.Helpers.shared_account_id(),
      socket.assigns.monitor.logical_name
    )

    # set status page components if status page exists
    if status_page do
      # subscription components that were enabled in configuring
      component_ids =
        socket.assigns.component_enabled_state
        |> Enum.filter(fn {_component_id, enabled} -> enabled end)
        |> Enum.map(fn {component_id, _enabled} -> component_id end)

      # batch all subscription add and remove actions
      Helpers.dispatch_with_auth_check(socket, %StatusPageCmds.SetSubscriptions{
        id: status_page.id,
        account_id: socket.assigns.current_user.account_id,
        component_ids: component_ids
      })
    end

    case Helpers.dispatch_with_auth_check(socket, cmd) do
      {:error, _} -> send(self(), {:stop_configuring, nil, nil, []})
      _ -> send(self(), {:stop_configuring, socket.assigns.analyzer_config, socket.assigns.component_enabled_state})
    end
    {:noreply, socket}
  end

  def handle_event("page-component-subscription-select-all", _target, socket) do
    all_selected? = Enum.all?(Map.values(socket.assigns.component_enabled_state), &(&1 == true))
    updated_enable_states =
      if (all_selected?) do
        Enum.map(socket.assigns.component_enabled_state, fn {component, _enabled} -> {component, false} end) |> Map.new()
      else
        Enum.map(socket.assigns.component_enabled_state, fn {component, _enabled} -> {component, true} end) |> Map.new()
      end

    {:noreply, socket |> assign(component_enabled_state: updated_enable_states)}
  end

  def handle_event("page-component-subscription", %{"toggle_component_subscription" => checkbox_params} = _target, socket) do
    %{"component_id" => component_id} = checkbox_params

    new_toggle_value = not Map.get(socket.assigns.component_enabled_state, component_id)
    new_component_enabled_state = Map.put(socket.assigns.component_enabled_state, component_id, new_toggle_value)

    {:noreply, socket |> assign(component_enabled_state: new_component_enabled_state)}
  end

  defp assign_check_errors(%{ assigns: %{ check_errors: existing_check_errors } } = socket, check_logical_name, errors) do
    socket
    |> assign(check_errors: Map.put(existing_check_errors, check_logical_name, errors))
  end

  defp remove_check_config(analyzer_config, check_logical_name) do
    new_check_configs =
      analyzer_config.check_configs
      |> Enum.reject(fn config -> Map.get(config, "CheckId") == check_logical_name end)

    %AnalyzerConfig{ analyzer_config | check_configs: new_check_configs}
  end

  defp update_check_config(analyzer_config, check_logical_name, updated_check_config) do
    new_check_configs =
      analyzer_config.check_configs
      |> Enum.reject(fn config -> Map.get(config, "CheckId") == check_logical_name end)

    new_check_configs = [ updated_check_config | new_check_configs]
    %AnalyzerConfig{ analyzer_config | check_configs: new_check_configs}
  end

  defp prepare_analyzer_config(%{assigns: %{analyzer_config: analyzer_config, active_checks: active_checks, active_instances: active_instances}} = socket) do
    analyzer_config = AnalyzerConfig.fill_empty_with_defaults(analyzer_config)
    |> maybe_update_instances(active_instances)
    |> maybe_update_check_configs(active_checks)

    socket
    |> assign(analyzer_config: analyzer_config)
  end

  defp maybe_update_instances(analyzer_config, active_instances) do
    case Enum.empty?(analyzer_config.instances) do
      true -> Map.put(analyzer_config, :instances, active_instances)
      false -> analyzer_config
    end
  end

  defp maybe_update_check_configs(analyzer_config, active_checks) do
    case Enum.empty?(analyzer_config.check_configs) do
      true ->
        check_configs = active_checks
        |> List.flatten()
        |> Enum.uniq_by(& &1.logical_name)
        |> Enum.map(fn active_check ->
          active_check.logical_name
          |> CheckConfig.get_empty()
          |> CheckConfig.to_csharp_map()
        end)
        Map.put(analyzer_config, :check_configs, check_configs)
      false -> analyzer_config
    end
  end

  defp show_add_region_button(monitor_instances, active_instances) do
    recent_instances = monitor_instances
      |> get_recent_instances
      |> Enum.map(fn item -> item.instance_name end)
    # only show button if there are still recent_instances that can be added
    not MapSet.subset?(
      MapSet.new(recent_instances),
      MapSet.new(active_instances)
    )
  end

  defp get_available_instances(monitor_instances, active_instances) do
    monitor_instances
    |> Enum.reject(fn item -> Enum.any?(active_instances, fn active -> active == item.instance_name end) end)
    |> get_recent_instances
  end

  defp get_recent_instances(instances) do
    one_day_ago = NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-60*60*24)
    instances
      |> Enum.reject(fn item -> NaiveDateTime.compare(item.last_report, one_day_ago) == :lt end)
  end

  defp can_save(errors, _, _, _) when errors != %{}, do: false
  defp can_save(_, check_errors, analyzer_config,account_id) do
    monitor_logical_name = analyzer_config.monitor_logical_name
    Enum.all?(check_errors, fn {_key, val} -> val == %{} end)
    &&
    (
      length(analyzer_config.check_configs) >= 1
      ||
      Helpers.status_page_only_monitor?(account_id,monitor_logical_name)
    )
  end

  def threshold_input(assigns) do
    assigns = assigns
    |> assign_new(:use_time_dropdown, fn -> false end) # TODO: Implement
    |> assign_new(:tooltip, fn -> "No tooltip" end)
    |> assign_new(:errors, fn -> %{} end)
    |> assign_new(:id_suffix, fn -> "" end)

    ~H"""
    <div class="mb-3">
      <div class="flex flex-col md:flex-row">
        <div class="flex flex-grow items-center w-full md:max-w-[80%]">
          <label for={"#{@threshold_input_id}#{@id_suffix}"} class="font-bold">
            <%= @threshold_label %>&nbsp;
            <span
              class="ml-1"
              x-data={"{ tooltip: '#{@tooltip}'}"}
              x-tooltip="tooltip"
            >
              <%= svg_image("icon-info", class: "inline")%>
            </span>
          </label>
        </div>
        <div class="w-full md:w-1/6 md:ml-auto">
          <%= if @is_read_only do %>
            <%= @value %>
          <% else %>
            <input type="number" name={"#{@threshold_input_id}"} id={"#{@threshold_input_id}#{@id_suffix}"} value={"#{@value}"} />
          <% end %>
        </div>
      </div>
      <%= if Map.has_key?(@errors, String.to_atom(@threshold_input_id)) do %>
      <div class="mt-3">
        <.alert color="danger" label={Map.get(@errors, String.to_atom(@threshold_input_id))} />
      </div>
      <% end %>
    </div>
    """
  end

  def try_threshold_parse(threshold, compare_to, :default_degraded_timeout), do: do_try_threshold_parse(threshold, 0, compare_to.default_error_timeout)
  def try_threshold_parse(threshold, compare_to, :default_error_timeout), do: do_try_threshold_parse(threshold, compare_to.default_degraded_timeout, @default_check_timeout)
  def try_threshold_parse(threshold, compare_to, :degraded_timeout), do: do_try_threshold_parse(threshold, 0, compare_to.error_timeout)
  def try_threshold_parse(threshold, compare_to, :error_timeout), do: do_try_threshold_parse(threshold, compare_to.degraded_timeout, @default_check_timeout)
  def try_threshold_parse(threshold, _compare_to, _), do: do_try_threshold_parse(threshold, 0, :infinite)

  defp do_try_threshold_parse(threshold, min, max) do
    case Float.parse(threshold) do
      {floatValue, ""} ->
        case max do
          :infinite -> if floatValue <= min, do: { :invalid, get_translated_threshold_value(floatValue, threshold), "Please enter a number above #{min}." }, else: { :ok, floatValue }
          max -> if (floatValue <= max && floatValue >= min), do: { :ok, floatValue}, else: { :invalid, get_translated_threshold_value(floatValue, threshold), "Please enter a number between #{min} and #{max}." }
        end
      _ ->
        { :invalid, threshold, "Please enter a number between #{min} and #{max}." }
    end
  end

  def get_translated_threshold_value(float_value, :degraded_threshold), do: float_value / 100
  def get_translated_threshold_value(float_value, :default_degraded_threshold), do: float_value / 100
  def get_translated_threshold_value(float_value, _), do: trunc(float_value)

  defp handle_threshold_change(threshold_value, threshold, socket, additional_message \\ "") do
    socket = case BackendWeb.MonitorDetailLiveConfigure.try_threshold_parse(threshold_value, socket.assigns.analyzer_config, threshold) do
      { :invalid, value, msg } ->
        updated_analyzer_config =
          Map.put(socket.assigns.analyzer_config,
          threshold,
          value)

        socket
        |> assign( analyzer_config: updated_analyzer_config)
        |> assign(errors: Map.put(socket.assigns.errors, threshold, "#{msg} #{additional_message}"))
      { :ok, floatValue} ->
        updated_analyzer_config =
          Map.put(socket.assigns.analyzer_config,
          threshold,
          BackendWeb.MonitorDetailLiveConfigure.get_translated_threshold_value(floatValue, threshold))

        socket
        |> assign( analyzer_config: updated_analyzer_config)
        |> assign(errors: Map.delete(socket.assigns.errors, threshold))
      end
      socket
  end
end
