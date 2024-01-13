defmodule BackendWeb.DemoMonitorDetailLive do
@moduledoc """
This LiveView is used as a Metrist Demo to show details for a given SHARED monitor

The existing components specifically BackendWeb.MonitorDetailLiveRead and its child components
are reused here as there is simply too much logic to duplicate out

current_user is nil in session as no user is actually logged in here

Some functions that are used are identical to those in MonitorDetailLive, those functions use defdelegate

Since SHARED does not have any status page subscriptions, the StatusPageSubscriptions component is told
to show all status page components on the details page for the sake of the demo.

current_user is still used for auth checks in the used components but account_id is explicitly passed in
so that it doesn't have to go to current_user or the socket to get that.

Monitor Status Rendering has also been moved out to a component so that it could be used both on this LiveView
and as well as the existing MonitorDetails LiveView without duplication

This LiveView can be edited for copy etc. freely without impacting the main Monitor Details page

Note: Since we don't currently send a pubsub broadcast for SHARED snapshot changes (as they don't generate any alerts),
refreshes of the demo page are required to see state updates
"""
  use BackendWeb, :live_view

  alias BackendWeb.MonitorDetailLive

  require Logger

  @impl true
  def mount(params, _session, socket) do
    limit_memory()

    # demo page only accesses the SHARED data
    account_id="SHARED"

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
        show_link_to_check_details?: false,
        provider_icon: nil,
        status_page: nil,
        status_page_state: :up,
        status_page_incident_start_time: NaiveDateTime.utc_now(),
        duration_message_rand: 0,
        duration_message_rand_timer_ref: nil,
        maybe_date: nil,
        # simulate no user/banners even if a user is logged in (Allowing demo to work the same way even if logged in)
        current_user: nil,
        banner_notices: nil,
        analyzer_config: Backend.Projections.get_analyzer_config(account_id, monitor_logical_name)
      )

    if connected?(socket) do
      subscribe_to_pubsub_if_connected(account_id, monitor_logical_name)
      send(self(), :update_displayed_duration)
    end

    {:ok, socket}
  end

  # identical work to MonitorDetailLive so delegate
  defdelegate subscribe_to_pubsub_if_connected(account_id, monitor_logical_name), to: MonitorDetailLive
  defdelegate has_active_status_page_subscriptions?(status_page_subscriptions), to: MonitorDetailLive

  # pub sub handling is identical here to MonitorDetailLive so let's just delegate the handle_info
  @impl true
  defdelegate handle_info(msg, socket), to: MonitorDetailLive

  # handle_params handling is identical here to MonitorDetailLive so let's just delegate the handle_info
  @impl true
  defdelegate handle_params(params, url, socket), to: MonitorDetailLive

end
