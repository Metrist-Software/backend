defmodule BackendWeb.DemoMonitorsLive do
@moduledoc """
This LiveView is used as a Metrist Demo to list off all SHARED monitors

It will show their state and allow them to be clicked to go into a public "DEMO" version
of the Monitor Details view

current_user is nil in session as no user is actually logged in here

Some functions that are used are identical to those in MonitorsLive, those functions use defdelegate

This LiveView can be edited for copy etc. freely without impacting the main Monitors LiveView

Note: Since we don't currently send a pubsub broadcast for SHARED snapshot changes (as they don't generate any alerts),
refreshes of the demo page are required to see state updates
"""
  use BackendWeb, :live_view

  alias Backend.Projections

  alias BackendWeb.MonitorsLive

  @impl true
  def mount(params, _session, socket) do
    limit_memory()

    monitors = Projections.list_monitors(nil, [:analyzer_config, :monitor_tags])
      |> Map.new(& {&1.logical_name, with_snapshot(&1)})

    status_page_names = Backend.Projections.status_pages()
      |> Enum.map(fn sp -> sp.name end)

    initial_filter = case params do
      %{"tag" => tag} -> {:parent, tag}
      %{"id" => id} -> {:child, id}
      _ -> nil
    end

    socket =
      socket
      |> assign(
        all_monitors: monitors,
        grouped_monitors: %{},
        hide_breadcrumb: true,
        page_title: "Metrist Demo",
        status_page_names: status_page_names,
        filter_list_group_data: [],
        initial_list_group_filter: initial_filter,
        search: nil,
        actual_query_params: nil,
        # simulate no user/banners even if a user is logged in (Allowing demo to work the same way even if logged in)
        current_user: nil,
        banner_notices: nil,
        # it is an anonymous page, so we never need spoofing detection.
        spoofing?: false
        )
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = socket
      |> assign_grouped_monitors(params)
      |> assign(actual_query_params: params)

   {:noreply, socket}
  end

  # We're not working with displayed monitors here - we're instead just showing all SHARED monitors
  # This is a different assign_grouped_monitors to handle
  defp assign_grouped_monitors(%{assigns: assigns} = socket, params) do
    %{all_monitors: monitors} = assigns

    search = case params do
      %{"id" => monitor}  ->  %{"id" => monitor}
      %{"tag" => tag} -> %{"tag" => tag}
      _ -> %{}
    end
    |> Map.put("status", Map.get(params, "status", "all"))

    grouped_monitors = MonitorsLive.group_monitors(monitors, search)
    unfiltered_grouped_monitors = MonitorsLive.group_monitors(monitors)

    assign(socket,
      grouped_monitors: grouped_monitors,
      search: search,
      filter_list_group_data: monitor_listgroup_data(unfiltered_grouped_monitors)
    )
  end

  @impl true
  # filter function handlers (very similar to MonitorLive handlers but targeting the demo path)
  def handle_info({:list_group_parent_selected, id, _}, socket) do
    params = socket.assigns.search
    |> Map.delete("id")
    |> Map.put("tag", id)

    {:noreply, push_patch(socket, to: Routes.demo_monitors_path(socket, socket.assigns.live_action, params), replace: true)}
  end

  def handle_info({:list_group_child_selected, id}, socket) do
    params = socket.assigns.search
    |> Map.delete("tag")
    |> Map.put("id", id)

    {:noreply, push_patch(socket, to: Routes.demo_monitors_path(socket, socket.assigns.live_action, params), replace: true)}
  end

  def handle_info(:list_group_select_cleared, socket) do
    params = socket.assigns.search
    |> Map.delete("tag")
    |> Map.delete("id")

    {:noreply, push_patch(socket, to: Routes.demo_monitors_path(socket, socket.assigns.live_action, params), replace: true)}
  end

  # snapshot change handler (Similar to MonitorLive but targeting a different assign)
  def handle_info({:snapshot_state_changed, _acc, monitor_logical_name, monitor_state}, socket) do
    {:noreply,
     socket
     |> update_snapshot(monitor_logical_name, monitor_state, :all_monitors)
    }
  end

  # default handler
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear-filters", _, socket) do
    {:noreply, push_patch(socket, to: Routes.demo_monitors_path(socket, :index), replace: true)}
  end

  # delegates to MonitorLive as these are identical
  defdelegate monitor_listgroup_data(grouped_monitors), to: MonitorsLive

  defdelegate render_select_by_status_label(status), to: MonitorsLive

  defdelegate maybe_override_search_and_list(grouped_monitors, unfiltered_grouped_monitors, search, status_param), to: MonitorsLive

  # private helpers
  @get_snapshot &Backend.RealTimeAnalytics.get_snapshot_or_nil/2

  defp with_snapshot(monitor) do
    # If we want a snapshot, we also want a change subscription.
    Backend.PubSub.subscribe_snapshot_state_changed("SHARED", monitor.logical_name)
    snapshot = @get_snapshot.("SHARED", monitor.logical_name)
    Map.put(monitor, :snapshot, snapshot)
  end

  defp update_snapshot(socket, monitor_logical_name, monitor_state, which) do
    monitors = Map.get(socket.assigns, which)
    monitor = Map.get(monitors, monitor_logical_name)
    if monitor != nil and snapshot_state(monitor.snapshot) != monitor_state do
      monitor = with_snapshot(monitor)
      assign(socket, which, Map.put(monitors, monitor_logical_name, monitor))
    else
      socket
    end
  end

  defp header_id(name) do
    "#{String.replace(name, ~r"\s", "")}-header"
  end
end
