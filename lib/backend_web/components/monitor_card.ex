defmodule BackendWeb.Components.MonitorCard do
  import BackendWeb.Helpers

  use BackendWeb, :component

  def render(assigns) do
    # Set defaults
    assigns = assigns
    |> assign_new(:link_target, fn -> BackendWeb.MonitorDetailLive end)
    |> assign_new(:monitor, fn -> nil end)
    |> assign_new(:group, fn -> "" end)

    ~H"""
    <.link navigate={Routes.live_path(BackendWeb.Endpoint, @link_target, @monitor.logical_name)}>
      <div data-cy="monitor-link" class={"flex overflow-hidden border-l-8 border rounded-lg p-2 items-center #{monitor_border_class(@monitor)}"}>
        <%= live_component BackendWeb.Components.SafeImage,
          id: "#{@group}-#{@monitor.logical_name}",
          src: image_url(@monitor),
          class: "w-14 h-14",
          alt: @monitor.name
        %>

        <div class="pl-4 py-2 flex-grow">
          <h3 class="text-normal font-bold content-center">
            <%= @monitor.name %>
          </h3>

          <div class="flex flex-row items-center justify-between">
            <BackendWeb.Components.MonitorStateBadge.render
              state={get_state_for_badge_and_border(@monitor)}
              class="py-1 px-2 mt-1 mr-1 w-18 h-18"
              show_icon={false}
            />

            <span :if={is_beta(@monitor)} class="pill px-2 py-1 bg-blue !font-lato dark:text-white">Beta</span>

            <div class="flex flex-row dark:text-white">
              <div :if={has_in_app_monitoring(@monitor)} class="mr-1" x-data={"{ tooltip: 'In-App Monitoring'}"}  x-tooltip="tooltip">
                <%= svg_image("icon-in-app", "monitors")%>
              </div>
              <div :if={has_functional_testing(@monitor)} class="mr-1" x-data={"{ tooltip: 'End-to-end Functional Testing'}"}  x-tooltip="tooltip">
                <%= svg_image("icon-functional-testing", "monitors")%>
              </div>
              <div :if={has_status_component_feed(@monitor.logical_name, @status_page_names)} x-data={"{ tooltip: 'Status Component Feed'}"}  x-tooltip="tooltip">
                <%= svg_image("icon-status-component", "monitors")%>
              </div>
            </div>

          </div>
        </div>
      </div>
    </.link>
    """
  end

  defp is_beta(monitor) do
    tags = merged_tags(monitor)
    "metrist.beta:true" in tags
  end

  defp has_in_app_monitoring(monitor) do
    require Logger
    tags = merged_tags(monitor)
    Logger.debug("has in app monitoring? #{monitor.logical_name}")
    Logger.debug(" -   tags = #{inspect tags}")
    "metrist.source:in-process" in tags
  end
  defp has_functional_testing(monitor) do
    tags = merged_tags(monitor)
    "metrist.source:monitor" in tags
  end
  defp has_status_component_feed(monitor_name, status_page_names) do
    Enum.member?(status_page_names, monitor_name)
  end

  defp merged_tags(monitor) do
    Backend.Projections.Dbpa.Monitor.get_tags(monitor)
  end

  defp monitor_border_class(%{snapshot: nil} = _monitor) do
    "#{BackendWeb.Helpers.get_monitor_status_border_class(nil)}"
  end
  defp monitor_border_class(monitor) do
    case get_state_for_badge_and_border(monitor) do
      :up -> "border-gray-500 border-l-healthy"
      state -> "#{BackendWeb.Helpers.get_monitor_status_border_class(state)}"
    end
  end

  defp get_state_for_badge_and_border(monitor) do
    case snapshot_state(monitor.snapshot) do
      :up ->
        if is_nil(Backend.StatusPage.Helpers.url_for(monitor.logical_name)) do
          :up
        else
          BackendWeb.Helpers.status_page_state_from_snapshot(monitor.snapshot)
        end
      _ ->  snapshot_state(monitor.snapshot)
    end
  end

  def image_url(mon) do
    monitor_image_url(short_id(mon))
  end

  defp short_id(mon) do
    String.replace(mon.logical_name, "Monitors/", "")
  end
end
