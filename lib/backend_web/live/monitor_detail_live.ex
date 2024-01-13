defmodule BackendWeb.MonitorDetailLive do
  use BackendWeb, :live_view

  alias Backend.Projections.Dbpa.StatusPage
  alias Backend.Projections.Dbpa.StatusPage.StatusPageComponent
  alias Backend.Projections.Dbpa.StatusPage.StatusPageSubscription
  alias BackendWeb.Components.StatusPage.StatusPageComponentInterface, as: ComponentInterface

  require Logger

  @snapshot_up :up

  @impl true
  def mount(params, session, socket) do
    limit_memory()

    account_id = session["current_user"].account_id
    monitor_logical_name = params["monitor"]

    socket =
      socket
      |> assign(
        account_id: account_id,
        monitor_logical_name: monitor_logical_name,
        page_title: monitor_logical_name,
        snapshot: nil,
        configuring: false,
        analyzer_config: nil,
        monitor: nil,
        notices: [],
        full_width: true,
        recent_unhealthy_event: nil,
        show_link_to_check_details?:
          show_link_to_check_details?(session["current_user"].account_id),
        provider_icon: nil,
        status_page: nil,
        status_page_state: :up,
        status_page_incident_start_time: NaiveDateTime.utc_now(),
        duration_message_rand: 0,
        duration_message_rand_timer_ref: nil,
        maybe_date: nil
      )
      |> mount_initial_analyzer_config()

    if connected?(socket) do
      subscribe_to_pubsub_if_connected(account_id, monitor_logical_name)
      send(self(), :update_displayed_duration)
    end

    {:ok, socket}
  end

  def subscribe_to_pubsub_if_connected(account_id, monitor_logical_name) do
    Backend.PubSub.subscribe_snapshot_state_changed(account_id, monitor_logical_name)
  end

  # TODO this is a hack for MET-523. Only accounts created before the cutoff date
  # are shown a link to the check details page.
  @details_cutoff_date ~N[2022-03-03T00:00:00.000Z]
  defp show_link_to_check_details?(account_id) do
    acct = Backend.Projections.get_account!(account_id)
    NaiveDateTime.compare(acct.inserted_at, @details_cutoff_date) == :lt
  end

  # after the initial mount, the handle_info calls will update the config based on changes from the configuration view
  defp mount_initial_analyzer_config(
         %{assigns: %{monitor_logical_name: monitor_logical_name, current_user: current_user}} =
           socket
       ) do
    analyzer_config =
      Backend.Projections.get_analyzer_config(current_user.account_id, monitor_logical_name)

    socket
    |> assign(analyzer_config: analyzer_config)
  end

  @impl true
  def handle_info(
        {:configure_check_updated,
         %{
           check_logical_name: check_logical_name,
           updated_check_config: updated_check_config,
           errors: errors
         }},
        socket
      ) do
    send_update(BackendWeb.MonitorDetailLiveConfigure,
      id: "configure_component",
      check_logical_name: check_logical_name,
      updated_check_config: updated_check_config,
      errors: errors
    )

    {:noreply, socket}
  end

  def handle_info(
        {:configure_check_errors_updated,
         %{check_logical_name: check_logical_name, errors: errors}},
        socket
      ) do
    send_update(BackendWeb.MonitorDetailLiveConfigure,
      id: "configure_component",
      check_logical_name: check_logical_name,
      errors: errors
    )

    {:noreply, socket}
  end

  def handle_info({:stop_configuring, analyzer_config, component_enabled_state}, socket) do
    subscription_component_states = if component_enabled_state do
      Enum.map(socket.assigns.subscription_component_states, fn sub ->
        %{sub | enabled: Map.get(component_enabled_state, sub.status_page_component_id, false)}
      end)
    end

    {:noreply,
     socket
     |> assign(
       analyzer_config: analyzer_config || socket.assigns.analyzer_config,
       subscription_component_states: subscription_component_states || socket.assigns.subscription_component_states,
       configuring: false,
       full_width: false
     )
     |> load_status_page_data()
    }
  end

  def handle_info(:start_configuring, socket) do
    {:noreply,
     socket
     |> assign(
       configuring: true,
       full_width: true
     )}
  end

  def handle_info(:update_displayed_duration, socket) when socket.assigns.snapshot.state != :up do
    socket =
      if socket.assigns.recent_unhealthy_event == nil do
        maybe_assign_recent_unhealthy_event(socket)
      else
        socket
      end

    {:noreply,
     assign(socket,
       duration_message_rand: System.unique_integer([:monotonic]),
       duration_message_rand_timer_ref:
         Process.send_after(self(), :update_displayed_duration, :timer.minutes(1))
     )}
  end

  def handle_info(:update_displayed_duration, socket) do
    if timer_ref = socket.assigns.duration_message_rand_timer_ref do
      Process.cancel_timer(timer_ref)
    end

    {:noreply, assign(socket, duration_message_rand_timer_ref: nil)}
  end

  def handle_info({:snapshot_state_changed, account_id, monitor_logical_name, _monitor_state}, socket) do
    send(self(), :update_displayed_duration)

    socket =
      socket
      |> assign(:snapshot, Backend.RealTimeAnalytics.get_snapshot_or_nil(account_id, monitor_logical_name))
      |> assign(:recent_unhealthy_event, nil)
      |> assign(:maybe_date, DateTime.utc_now() |> DateTime.to_unix())

    {:noreply, socket}
  end

  def handle_info(_catchall, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    snapshot = Backend.RealTimeAnalytics.get_snapshot_or_nil(socket.assigns.account_id, socket.assigns.monitor_logical_name)

    monitor =
      Backend.Projections.get_monitor(
        socket.assigns.account_id,
        socket.assigns.monitor_logical_name
      )

    {:noreply, do_handle_params(socket, monitor, snapshot)}
  end

  defp do_handle_params(socket, monitor, snapshot) when is_nil(monitor) or is_nil(snapshot) do
    case error_state(monitor, snapshot) do
      :ok ->
        socket

      {type, :monitor} ->
        put_flash(socket, type, "Monitor does not exist")

      {type, :snapshot} ->
        put_flash(
          socket,
          type,
          "No data available for this monitor. If you've recently added it to your account, it may take a few minutes to generate"
        )
    end
  end

  defp do_handle_params(socket, monitor, snapshot) do
    assign(socket,
      page_title: monitor.name,
      snapshot: snapshot,
      monitor: monitor
    )
    |> load_notices(monitor.logical_name)
    |> maybe_assign_recent_unhealthy_event()
    |> maybe_assign_status_page(monitor.logical_name)
    |> load_status_page_component_states()
    |> load_status_page_data()
    |> assign_provider_icon()
  end

  defp maybe_assign_status_page(socket, monitor_logical_name) do
    status_page = Backend.StatusPage.Helpers.url_for(monitor_logical_name)

    assign(socket, status_page: status_page)
  end

  defp load_notices(socket, monitor_logical_name) do
    notices = Backend.Projections.active_notices_by_monitor_id(monitor_logical_name)

    socket
    |> assign(notices: notices)
  end

  defp maybe_assign_recent_unhealthy_event(%{assigns: assigns} = socket)
       when assigns.snapshot.state == :up,
       do: socket

  defp maybe_assign_recent_unhealthy_event(%{assigns: assigns} = socket) do
    account_id = assigns.account_id

    # The first event for a given correlation ID will be the event when it went from :up to another state
    # and we want the total time since it was last healthy

    event =
      Backend.Projections.first_event_for_correlation_id(
        account_id,
        assigns.snapshot.correlation_id
      )

    assign(socket, recent_unhealthy_event: event)
  end

  defdelegate requires_status_component_subscription?(monitor_logical_name), to: Backend.StatusPage.Helpers

  defp error_state(nil, _snapshot), do: {:error, :monitor}
  defp error_state(_monitor, nil), do: {:info, :snapshot}
  defp error_state(_monitor, _snapshot), do: :ok

  @doc false
  def load_instances_and_checks(
        socket,
        account_id,
        monitor_logical_name,
        analyzer_config,
        snapshot
      ) do

    monitor_instances = do_load_instances(account_id, monitor_logical_name)

    account_checks = Backend.Projections.get_checks(account_id, monitor_logical_name)

    snapshot_checks = snapshot.check_details

    non_snapshot_checks =
      account_checks
      |> Enum.reject(fn check ->
        Enum.any?(snapshot_checks, &(&1.check_id == check.logical_name))
      end)
      |> Enum.map(fn check ->
        %{
          average: nil,
          check_id: check.logical_name,
          created_at: check.inserted_at,
          current: nil,
          instance: nil,
          last_checked: nil,
          message: nil,
          name: check.name,
          state: nil
        }
      end)

    check_details = snapshot_checks ++ non_snapshot_checks

    checks =
      check_details
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.check_id)
      |> Enum.uniq()
      |> Enum.map(fn logical_name ->
        details = Enum.filter(check_details, &(&1.check_id == logical_name))

        check = Enum.find(account_checks, &(&1.logical_name == logical_name))

        if !is_nil(check) do
          instances =
            Enum.filter(details, fn detail ->
              Enum.any?(monitor_instances, &(&1.instance_name == detail.instance))
            end)

          name = if logical_name == check.name do
            Backend.Docs.Generated.Checks.name(monitor_logical_name, logical_name)
          else
            check.name
          end

          Map.merge(
            check,
            %{
              name: name,
              instances: instances,
              state:
                instances
                |> Enum.map(& &1.state)
                |> Enum.reduce(
                  @snapshot_up,
                  &Backend.Projections.Dbpa.Snapshot.get_worst_state(&1, &2)
                ),
              last_checked:
                instances
                |> Enum.map(& &1.last_checked)
                |> most_recent_date(),
              active: determine_active_check(check, analyzer_config)
            }
          )
        end
      end)
      |> Enum.reject(&is_nil/1)

    account_configs = Backend.Projections.get_monitor_configs(account_id, monitor_logical_name)

    active_checks =
      checks
      |> Enum.filter(& &1.active)
      |> sort_by_step_order(account_configs)

    monitor_instance_names = Enum.map(monitor_instances, & &1.instance_name)

    active_instances =
      determine_active_instances(monitor_instance_names, analyzer_config)
      |> remove_unavailable_list_options(monitor_instance_names)

    has_private_instances = Backend.Projections.has_monitor_instances(account_id)

    socket
    |> assign(
      checks: checks,
      active_checks: active_checks,
      active_instances: Enum.sort(active_instances),
      instances: Enum.sort(monitor_instances, &(&1.instance_name < &2.instance_name)),
      has_private_instances: has_private_instances
    )
  end

  defp do_load_instances(account_id, monitor_logical_name) do
    Backend.Projections.get_monitor_instances(account_id, monitor_logical_name)
  end

  defp remove_unavailable_list_options(list, options) do
    Enum.filter(list, &Enum.member?(options, &1))
  end

  # Public for testing
  def sort_by_step_order([], _), do: []

  def sort_by_step_order(checks, configs) do
    ordered_checks =
      configs
      |> Enum.map(fn mc -> order_checks_in_step_order(mc, checks) end)

    all_steps =
      configs
      |> Enum.flat_map(& &1.steps)

    other_checks =
      checks
      |> Enum.reject(fn check ->
        Enum.any?(all_steps, fn step -> step.check_logical_name == check.logical_name end)
      end)

    case ordered_checks do
      [] -> [[], other_checks]
      _ -> ordered_checks ++ [other_checks]
    end
  end

  defp order_checks_in_step_order(monitor_config, checks) do
    monitor_config.steps
    |> Enum.reduce([], fn s, acc ->
      check =
        Enum.find_value(checks, nil, fn check ->
          if check.logical_name == s.check_logical_name, do: check
        end)

      [check | acc]
    end)
    |> Enum.reverse()
    # active: false checks won't be found and will produce nil
    |> Enum.reject(&is_nil/1)
  end

  def load_status_page_data(socket) do
    subscribed_components = socket.assigns.subscription_component_states
    |> Enum.filter(& &1.enabled)
    |> Enum.map(& &1.name)

    {current_state, start_time} = BackendWeb.Helpers.get_status_page_data(socket.assigns.monitor_logical_name, subscribed_components)

    assign(socket,
      status_page_state: current_state,
      status_page_incident_start_time: start_time
    )
  end

  def load_status_page_component_states(%{assigns: %{account_id: account_id, monitor_logical_name: monitor_logical_name}} = socket) do
    with %{id: status_page_id}         <- StatusPage.status_page_by_name(Domain.Helpers.shared_account_id(), monitor_logical_name),
         status_page_subscriptions     <- StatusPageSubscription.subscriptions(account_id, status_page_id),
         existing_page_components      <- StatusPageComponent.components(Domain.Helpers.shared_account_id(), status_page_id),
         page_component_change_ids     <- Enum.map(existing_page_components, & &1.recent_change_id),
         component_changes             <- StatusPage.component_changes_from_change_ids(Domain.Helpers.shared_account_id(), page_component_change_ids),
         subscription_component_states <- ComponentInterface.page_components_with_status(existing_page_components, component_changes, status_page_subscriptions)
    do
      socket
      |> assign(account_id: account_id)
      |> assign(subscription_component_states: subscription_component_states)
    else
      _ ->
        socket
        |> assign(subscription_component_states: [])
    end
  end

  def has_active_status_page_subscriptions?(subscription_component_states) do
    subscription_component_states
    |> Enum.any?(fn %{enabled: enabled} -> enabled end)
  end

  defp assign_provider_icon(%{assigns: assigns} = socket) do
    icon = get_provider_icon_for_monitor(assigns.monitor.logical_name)
    assign(socket, provider_icon: icon)
  end

  def unhealthy_message(assigns) when assigns.state != :up do
    start_time = assigns.start_time || NaiveDateTime.utc_now()
    # Duration here is the most significant value of the duration
    # For example Timex.format_duration/2 can have a return value of "21 hours, 12 minutes, 34 seconds"
    # but we only care about the "21 hours"
    duration =
      Timex.diff(start_time, NaiveDateTime.utc_now(), :duration)
      |> format_duration()

    assigns =
      assign(assigns,
        duration: duration,
        human_readable_date: format_with_tz(start_time, assigns.timezone)
      )

    ~H"""
    <span
      class={unhealthy_message_class(@state)}
      x-data={"{ tooltip: 'Since #{@human_readable_date}' }"}
      x-tooltip="tooltip"
    >
      <%= unhealthy_message_text(@state) %>
      <span class="font-bold"><%= @duration %></span>
    </span>
    """
  end

  def unhealthy_message(assigns) do
    ~H""
  end

  defp determine_active_instances(monitor_instance_names, analyzer_config) do
    if analyzer_config.instances == [] do
       monitor_instance_names
    else
      analyzer_config.instances
    end
  end

  defp determine_active_check(check, analyzer_config) do
    Enum.empty?(analyzer_config.check_configs) ||
      Enum.any?(analyzer_config.check_configs, &(&1["CheckId"] == check.logical_name))
  end

  def most_recent_date(dates),
    do: Enum.max(dates, NaiveDateTime, fn -> ~N[1970-01-01 00:00:00] end)

  defp unhealthy_message_class(:down), do: "text-down"
  defp unhealthy_message_class(:issues), do: "text-issues"
  defp unhealthy_message_class(_), do: "text-degraded"
  defp unhealthy_message_text(_), do: "Unhealthy for"

  @spec format_duration(Timex.Duration.t()) :: String.t()
  def format_duration(duration) do
    if Timex.Duration.to_minutes(duration) |> abs < 1.0 do
      "Just now"
    else
      duration
      |> Timex.format_duration(:humanized)
      |> String.replace(~r/, [0-9]+ seconds.*/, "")
      # If we're under a minute, the starting comma of the previous regex will keep
      # it from triggering so we only drop the microseconds in that case
      |> String.replace(~r/, [0-9]+ microseconds.*/, "")
    end
  end
end
