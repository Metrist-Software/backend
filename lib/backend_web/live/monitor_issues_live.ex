defmodule BackendWeb.MonitorIssuesLive do
  use BackendWeb, :live_view
  require Logger

  @timespan_options [
    %{
      id: "5",
      vaue: 5,
      label: "5 minutes"
    },
    %{
      id: "10",
      value: 10,
      label: "10 minutes"
    },
    %{
      id: "30",
      value: 30,
      label: "30 minutes"
    },
    %{
      id: "60",
      value: 60,
      label: "1 hour"
    },
    %{
      id: "1440",
      value: 1440,
      label: "1 day"
    },
    %{
      id: "4320",
      value: 4320,
      label: "3 days"
    },
    %{
      id: "10080",
      value: 10080,
      label: "1 week"
    },
    %{
      id: "43800",
      value: 43800,
      label: "1 month"
    }
  ]
  @timespan_options_by_id Enum.into(@timespan_options, %{}, fn opt -> {opt.id, opt} end)

  @severity_options [
    %{id: "degraded", label: "Degraded", value: :degraded},
    %{id: "down", label: "Down", value: :down}
  ]
  @severity_options_by_id Enum.into(@severity_options, %{}, fn opt -> {opt.id, opt} end)

  @impl true
  def mount(params, session, socket) do
    current_user = session["current_user"]

    {account_id, timezone} =
      if session["demo"] do
        {Domain.Helpers.shared_account_id(), "UTC"}
      else
        {current_user.account_id, current_user.timezone || "UTC"}
      end

    page_title = if socket.assigns.live_action == :list_issues do
      page_title(nil)
    else
      page_title(params["monitor"])
    end

    socket =
      socket
      |> assign(
        page_title: page_title,
        timezone: timezone,
        account_id: account_id,
        query_meta: %Paginator.Page.Metadata{},
        expanded_issue_id: nil,
        issue_events: [],
        affected_info: %{},
        rows: [],
        timespan_options: @timespan_options,
        severity_options: @severity_options,
        filters: %{
          monitor: nil,
          timespan: nil,
          severity: nil
        },
        monitors: Backend.Projections.list_monitors(account_id)
      )
      |> assign_monitor_names_by_logical_name()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign_timespan(params)
      |> assign_monitor(params)
      |> assign_severity(params)
      |> assign(query_meta: %Paginator.Page.Metadata{})

    {:noreply, socket |> issues()}
  end

  @impl true
  def handle_event("expand_row", %{"id" => id}, socket) do
    issue_events =
      Backend.Projections.list_issue_events_paginated(socket.assigns.account_id, issue_id: id)

    socket =
      socket
      |> assign(:expanded_issue_id, id)
      |> assign(issue_events: issue_events.entries)

    {:noreply, socket}
  end

  def handle_event("collapse_row", _param, socket) do
    socket = assign(socket, :expanded_issue_id, nil)
    {:noreply, socket}
  end

  def handle_event("next_page", _, socket) do
    socket =
      socket
      |> issues(cursor_after: socket.assigns.query_meta.after)

    {:noreply, socket}
  end

  def handle_event("prev_page", _, socket) do
    socket =
      socket
      |> issues(cursor_before: socket.assigns.query_meta.before)

    {:noreply, socket}
  end

  defp page_title(nil), do: "Issues"
  defp page_title(monitor), do: "Issues - #{monitor}"

  defp assign_monitor_names_by_logical_name(socket) do
    assign(
      socket,
      :monitor_names_by_logical_name,
      Enum.into(socket.assigns.monitors, %{}, fn monitor ->
        {monitor.logical_name, monitor.name}
      end)
    )
  end

  defp issues(socket, opts \\ []) do
    assigns = socket.assigns

    opts =
      opts
      |> filter_by_start_time(assigns.filters)
      |> filter_by_service(assigns.filters)
      |> filter_by_severity(assigns.filters)

    %Paginator.Page{metadata: metadata, entries: rows} =
      Backend.Projections.list_issues_paginated(assigns.account_id, opts)

    issue_ids = Enum.map(rows, & &1.id)

    affected_info =
      Backend.Projections.services_impacted_count(assigns.account_id, issue_ids)
      |> Enum.into(%{}, &{&1.issue_id, &1})

    socket
    |> assign(rows: rows)
    |> assign(affected_info: affected_info)
    |> assign(query_meta: metadata)
  end

  defp duration(%{start_time: start_time, end_time: end_time} = assigns)
       when start_time != nil and end_time != nil do
    duration =
      NaiveDateTime.diff(start_time, end_time)
      |> Timex.Duration.from_seconds()
      |> Timex.format_duration(:humanized)
      |> String.replace(~r/, [0-9]+ seconds.*/, "")
      |> String.replace(~r/, [0-9]+ microseconds.*/, "")

    assigns = assign(assigns, duration: duration)

    ~H|<%= @duration %>|
  end

  defp duration(assigns), do: ~H||

  def assign_timespan(socket, %{"timespan" => timespan})
      when is_map_key(@timespan_options_by_id, timespan) do
    assign(socket, filters: %{socket.assigns.filters | timespan: timespan})
  end

  @default_timespan_minutes "4320"
  def assign_timespan(socket, _param) do
    assign(socket, filters: %{socket.assigns.filters | timespan: @default_timespan_minutes})
  end

  def assign_severity(socket, %{"severity" => severity})
      when is_map_key(@severity_options_by_id, severity) do
    assign(socket, filters: %{socket.assigns.filters | severity: severity})
  end

  def assign_severity(socket, _params) do
    assign(socket, filters: %{socket.assigns.filters | severity: nil})
  end

  def assign_monitor(socket, %{"monitor" => monitor}) do
    monitor = Enum.find(socket.assigns.monitors, &(&1.logical_name == monitor))

    case monitor do
      %{logical_name: logical_name} ->
        assign(socket,
          filters: %{socket.assigns.filters | monitor: logical_name}
        )

      _ ->
        assign_monitor(socket, nil)
    end
  end

  def assign_monitor(socket, _param) do
    assign(socket, filters: %{socket.assigns.filters | monitor: nil})
  end

  defp filter_by_start_time(other_opts, %{timespan: selected_timespan})
       when is_binary(selected_timespan) do
    start_time_after =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-String.to_integer(selected_timespan), :minute)

    Keyword.merge(other_opts, start_time_after: start_time_after)
  end

  defp filter_by_start_time(other_opts, _filters), do: other_opts

  defp filter_by_service(other_opts, %{monitor: service}) when is_binary(service) do
    Keyword.merge(other_opts, service: service)
  end

  defp filter_by_service(other_opts, _filters), do: other_opts

  defp filter_by_severity(other_opts, %{severity: severity}) when is_binary(severity) do
    if value = @severity_options_by_id[severity].value do
      Keyword.merge(other_opts, worst_state: value)
    else
      other_opts
    end
  end

  defp filter_by_severity(other_opts, _filters), do: other_opts

  slot :main_item, required: true
  slot :sub_items, required: true
  attr :show_sub_items, :boolean, required: true
  attr :sub_item_count, :integer, required: true
  def inner_multi_row_grid(assigns) do
    ~H"""
      <div class="flex flex-col h-full">
        <%= render_slot(@main_item) %>

        <div
          :if={@show_sub_items}
          class="flex-grow grid gap-1 mt-1"
          style={"grid-template-rows: repeat(#{@sub_item_count}, minmax(0, 1fr))"}
        >
          <%= render_slot(@sub_items) %>
        </div>
      </div>
    """
  end

  defp timespan_label(assigns) do
    assigns = %{label: @timespan_options_by_id[assigns.timespan].label}
    ~H|<%= @label %>|
  end

  defp severity_label(assigns) when assigns.severity != nil do
    assigns = %{label: @severity_options_by_id[assigns.severity].label}
    ~H|<%= @label %>|
  end

  defp severity_label(assigns), do: ~H|All|

  defp functionality_display_name(%{source: source} = assigns)
       when source == :monitor do
    ~H|<%= @check_logical_name %>|
  end

  defp functionality_display_name(%{source: source} = assigns)
       when source == :status_page do
    [_id, _region | rest] = String.split(assigns.component_id, "-") |> Enum.reverse()
    name = Enum.reverse(rest) |> Enum.join("-")
    assigns = %{name: name}
    ~H|<%= @name %>|
  end

  defp region(%{region: region}) when region != nil do
    {icon, region} =
      case String.split(region, ":") do
        ["az", region] -> {"azure-icon", region}
        ["aws", region] -> {"aws-icon", region}
        ["gcp", region] -> {"gcp-icon", region}
        [region] -> {"aws-icon", region}
      end

    assigns = %{icon: icon, region: region}

    ~H"""
    <div class="rounded-lg border-2 border-gray-300 flex w-fit items-center px-2 h-full">
      <%= BackendWeb.Helpers.Svg.svg_image(@icon, class: "w-6 h-6") %>
      <span class="pl-2"><%= @region %></span>
    </div>
    """
  end

  defp region(%{component_id: component_id}) when component_id != nil do
    [_id, region_name | _rest] = String.split(component_id, "-") |> Enum.reverse()
    assigns = %{region: region_name}
    ~H|<%= @region %>|
  end

  defp region(assigns), do: ~H||

  # Hide the region count for issues orginated from a statuspage-only monitor
  defp region_count(%{count: count} = assigns) when count > 0 do
    ~H|<span class="font-bold"><%= @count %></span> region(s) impacted|
  end

  defp region_count(assigns), do: ~H||

  def relative_path(socket, live_action, params)
      when live_action in [:list_issues, :demo_list_issues] do
    Routes.monitor_issues_path(socket, live_action, params)
  end

  def relative_path(socket, live_action, params)
      when live_action in [:monitor_issues, :demo_monitor_issues] do
    Routes.monitor_issues_path(socket, live_action, params.monitor, Map.drop(params, [:monitor]))
  end

  def url_params(filters, new_key, new_value) do
    Map.put(filters, new_key, new_value)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp prepend_all_options(options) do
    [%{id: "all", value: nil, label: "All"} | options]
  end

  defp source_image(:monitor), do: "icon-functional-testing"
  defp source_image(:status_page), do: "icon-status-component"

  defp source_tooltip(:monitor), do: "End-to-end Functional Testing"
  defp source_tooltip(:status_page), do: "Status Page Feed"
end
