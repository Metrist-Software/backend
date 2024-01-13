defmodule BackendWeb.Components.MonitorStatus do
  import BackendWeb.Helpers

  use BackendWeb, :component

  def render(assigns) do
    assigns = assigns
    |> assign_new(:timezone, fn -> "UTC" end)

    ~H"""
    <span class="whitespace-nowrap">
      <BackendWeb.Components.MonitorStateBadge.render
        state={@snapshot_state}
        show_icon={false}
        class="py-1 px-2 text-xs"
      />

      <.unhealthy_message
        state={@snapshot_state}
        duration_message_rand={@duration_message_rand}
        start_time={Map.get(@recent_unhealthy_event || %{}, :start_time)}
        timezone={@timezone} />
    </span>

    <%= if show_status_page_status?(@status_page, @has_status_page_subscriptions, @monitor_logical_name) do %>
    <span class="whitespace-nowrap">
      <span class="mx-1">/</span>
      <%= maybe_render_status_page(@status_page) %>
      <BackendWeb.Components.MonitorStateBadge.render
        state={@status_page_state}
        show_icon={false}
        class="py-1 px-2 text-xs"
      />
      <.unhealthy_message
        duration_message_rand={@duration_message_rand}
        state={@status_page_state}
        start_time={@status_page_incident_start_time}
        timezone={@timezone} />
    </span>
    <% end %>
    """
  end

  defdelegate requires_status_component_subscription?(monitor_logical_name), to: Backend.StatusPage.Helpers

  defp show_status_page_status?(status_page, has_status_page_subscriptions, monitor_logical_name) do
    if is_nil(status_page) do
      false
    else
      (!requires_status_component_subscription?(monitor_logical_name) || has_status_page_subscriptions)
    end
  end

  defp maybe_render_status_page(nil), do: nil

  defp maybe_render_status_page(status_page) do
    assigns = %{status_page: status_page}

    ~H"""
    <a
      href={@status_page}
      title="Link to status page"
      target="_blank"
      class="align-middle text-green-shade dark:text-green-bright"
    >
      <span class="underline text-sm">Status page</span>
      <Heroicons.arrow_top_right_on_square solid class="h-3 w-3 inline" />
    </a>
    """
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
