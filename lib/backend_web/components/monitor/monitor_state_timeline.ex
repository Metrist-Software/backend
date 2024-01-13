defmodule BackendWeb.Components.Monitor.MonitorStateTimeline do
  use BackendWeb, :live_component

  alias Backend.Projections.Dbpa.{Snapshot, MonitorEvent, MonitorCheck, StatusPage}
  alias Backend.Projections
  alias BackendWeb.Helpers
  alias BackendWeb.Components.StatusPage.StatusPageComponentInterface, as: ComponentInterface

  require Logger

  @mobile_breakpoints ["min", "sm"]

  @timeframe_configs %{
    90 => %{
      bar_representation: "1 day",
      hour_offset: 24,
      hour_range: 0..0,
      timeframe: "90 days",
      mobile_timeframe: "30 days"
    },
    30 => %{
      bar_representation: "8 hours",
      hour_offset: 8,
      hour_range: 0..23//8,
      timeframe: "30 days",
      mobile_timeframe: "10 days",
    },
    3  => %{
      bar_representation: "1 hour",
      hour_offset: 1,
      hour_range: 0..23,
      timeframe: "3 days",
      mobile_timeframe: "1 day"
    }
  }

  def mount(socket) do
    {
      :ok,
      assign(socket,
        events: [],
        monitor: nil,
        skip_render?: true,
        account_id: "SHARED",
        provider_name: "Status Page",
        is_mobile_view: false,
        mobile_view_days: 30,
        selected_datetime: nil,
        current_user: nil,
        timezone: nil,
        timeframe: 90,
        checks: %{}
      )
    }
  end

  def update(assigns, socket) do
    {:ok,
    socket
    |> assign(assigns)
    |> maybe_assign_render_data()}
  end

  defp maybe_assign_render_data(socket) do
    if not is_nil(Backend.StatusPage.Helpers.url_for(socket.assigns.monitor.logical_name)) do
      # some services should only show status page data when they have at more than one component subscription
      if Backend.StatusPage.Helpers.requires_status_component_subscription?(socket.assigns.monitor.logical_name) do
        assign_if_subscribed(socket)
      else
        assign_render_data(true, socket)
      end
    else
      assign_render_data(false, socket)
    end
  end

  defp assign_if_subscribed(socket) do
    socket
    |> is_subscribed
    |> assign_render_data(socket)
  end

  defp assign_render_data(true, socket) do
    socket
      |> assign(skip_render?: false)
      |> assign_timezone()
      |> assign_check_names()
      |> assign_timeline_dates()
      |> assign_monitor_event_statuses()
      |> assign_status_page_statuses()
  end
  defp assign_render_data(false, socket), do: assign(socket, skip_render?: true)

  defp is_subscribed(socket) do
    with %{id: status_page_id} <-
      StatusPage.status_page_by_name(Domain.Helpers.shared_account_id(), socket.assigns.monitor.logical_name),
    existing_page_components   <-
      StatusPage.StatusPageComponent.components(Domain.Helpers.shared_account_id(), status_page_id),
    status_page_subscriptions  <-
      StatusPage.StatusPageSubscription.subscriptions(socket.assigns.account_id, status_page_id)
    do
      ComponentInterface.any_component_with_subscription?(
        existing_page_components,
        status_page_subscriptions
      )
    else
      _err -> false
    end
  end

  defp assign_timezone(%{ assigns: %{ current_user: current_user } } = socket) when not is_nil(current_user) do
    assign(socket, timezone: current_user.timezone || "UTC")
  end
  defp assign_timezone(socket), do: assign(socket, timezone: "UTC")

  defp assign_check_names(%{ assigns: %{ monitor: monitor, account_id: account_id}} = socket) do
     checks = MonitorCheck.get_combined_checks_for_monitor(monitor.logical_name, account_id)
     |> Enum.map(&({&1.logical_name, &1.name}))
     |> Map.new()

     assign(
       socket,
       checks: checks
     )
  end

  defp assign_timeline_dates(%{assigns: assigns} = socket) do
    tz = assigns.timezone
    timeframe = assigns.timeframe
    now = Timex.now(tz)
    end_date = Timex.to_date(now)
    start_date = Date.add(end_date, -timeframe)
    timeline_datetimes = Date.range(start_date, end_date) |> make_timeline_datetimes(now, tz, timeframe)
    assign(socket, timeline_datetimes: timeline_datetimes)
  end


  def render(assigns) do
    if assigns.skip_render? do
      skip_render(assigns)
    else
      do_render(assigns)
    end
  end

  def handle_event("day-hover", %{"day" => datetime}, socket) do
    {:ok, dt, _} = DateTime.from_iso8601(datetime)
    zoned_datetime = DateTime.shift_zone!(dt, socket.assigns.timezone, Tzdata.TimeZoneDatabase)
    {:noreply, assign(socket, selected_datetime: zoned_datetime)}
  end

  def handle_event("timeframe-update", %{"timeframe" => timeframe}, socket) do
    timeframe = String.to_integer(timeframe)
    socket = socket
    |> assign(timeframe: timeframe)
    |> assign_timeline_dates()
    {:noreply, socket}
  end

  def handle_event("breakpoint-change", breakpoint, socket) do
    {:noreply, assign(socket, is_mobile_view: breakpoint in @mobile_breakpoints)}
  end

  defp timeframe_select(mobile, timeframe) do
    assigns = %{
      id: if(mobile, do: "mobile", else: "desktop"),
      mobile: mobile,
      timeframe: timeframe,
    }

    ~H"""
    <select id={"timeframe-selector-#{@id}"} name="timeframe" class="w-min">
      <%= options_for_select(timeframe_options(@mobile), @timeframe) %>
    </select>
    """
  end

  defp timeframe_options(is_mobile) do
    config_key = if is_mobile, do: :mobile_timeframe, else: :timeframe

    timeframe_configs()
    |> Enum.map(fn {key, config} ->
      {config[config_key], key}
    end)
  end

  defp days_ago_text(timeframe, is_mobile) do
    config_key = if is_mobile, do: :mobile_timeframe, else: :timeframe

    timeframe_configs()
    |> Map.get(timeframe)
    |> Map.get(config_key)
    |> then(& "#{&1} ago")
  end

  def do_render(assigns) do
    ~H"""
    <div phx-hook="MonitorTimeline" id="monitor_timeline" class="hidden md:block">
      <!-- Dummy element to host the hook -->
      <span phx-hook="ScreenBreakpointListener" id="breakpoint-listener"/>
      <div class="box p-3">
        <div class="sm:flex">
        <h3 class="text-lg font-bold flex-grow">Status reported by <%= @provider_name %>
          <%= if @snapshot.check_details != [], do: "vs Metrist", else: "" %>
        </h3>
          <div class="flex flex-col">
            <form phx-change="timeframe-update" phx-target={@myself} id="timeframe-form">
              <label><%= svg_image("icon-calendar", class: "inline fill-current w-5 h-5 mr-2") %>Last: </label>
              <%= timeframe_select(@is_mobile_view, @timeframe) %>
            </form>
            <span class="text-sm text-right">Each bar represents <%= bar_representation(@timeframe)%></span>
          </div>
        </div>

        <div class="flex">
          <div class="flex flex-col mr-4">
            <%= provider_image(@status_page_icon) %>
            <div class="w-7 h-7 inline"></div>
            <%= if @snapshot.check_details != [] do %>
              <%= svg_image("icon", "brand", class: "w-7 h-7 inline") %>
            <% end %>

          </div>

          <%= for {status, state, datetime, reversed_idx} <- List.zip([fill_state_changes(@status_page_statuses, @timeline_datetimes, @timeframe),
                                                    fill_state_changes(@event_states, @timeline_datetimes, @timeframe),
                                                    @timeline_datetimes,
                                                    Enum.to_list(length(@timeline_datetimes)..0)]),
                  date_string = format_date(datetime),
                  datetime_string = DateTime.to_iso8601(datetime) do %>
          <div
            data-day={datetime_string}
            class={"timeline-day flex-col border border-transparent hover:border-current rounded-md w-full #{if @snapshot.check_details == [], do: "h-7", else: ""} cursor-pointer #{if reversed_idx <= @mobile_view_days, do: "flex", else: "hidden md:flex"}"}
            title={date_string}
          >
            <div class={"#{timeline_class(status)} flex-grow rounded"} />
            <%= if @snapshot.check_details != [] do %>
              <%= if status != state do %>
              <div class="relative h-7 w-full">
                <div class="h-full flex items-center justify-center">
                  <div class="h-full w-0.5 bg-black dark:bg-gray-200" />
                </div>
                <div class="flex justify-center">
                  <div class="w-2 h-2 -mt-1 absolute top-1/2 rounded-full bg-black dark:bg-gray-200" />
                </div>
              </div>
              <% else %>
              <div class="relative h-7 w-full" />
              <% end %>

              <div class={"#{timeline_class(state)} #{fade_class(status == state)} flex-grow rounded"} />
            <% end %>
            </div>
          <% end %>
        </div>

        <div :if={@snapshot.check_details == []} class="flex space-x-4">
          <%= svg_image("icon", "brand", class: "w-7 h-7 inline") %>
          <.alert color="warning">
            <a href="https://docs.metrist.io/guides/orchestrator-installation.html" class="link">Download and configure Metrist</a> to compare actual availability to the vendor status page
          </.alert>
        </div>

        <div class="flex text-sm text-muted">
          <span class="w-7 mr-4"/> <!-- Needs to match spacing used by above provider_image block -->
          <div><%= days_ago_text(@timeframe, @is_mobile_view) %></div>
          <div class="ml-auto">Now</div>
        </div>
        <p class="alert alert-info border-1 mb-1 mt-2" role="alert"
           phx-click="lv:clear-flash"
           phx-value-key="info"><%= live_flash(@flash, :info) %></p>
      </div>
      <%= if @selected_datetime do %>
      <div id="monitor_timeline_hover" class="inline-block absolute invisible box z-40 w-[300px] sm:w-[573px]">
        <%= get_timeline_hover(@monitor, @account_id, @selected_datetime, @checks, @timeframe, @status_page_icon) %>
      </div>
      <% end %>
    </div>
    """
  end

  defp timeframe_configs, do: @timeframe_configs

  defp bar_representation(timeframe) do
    @timeframe_configs[timeframe].bar_representation
  end

  defp get_timeline_hover(monitor, account_id, datetime, checks, timeframe, status_page_icon) do
    start_datetime = datetime
    end_datetime = Timex.shift(start_datetime, hours: @timeframe_configs[timeframe].hour_offset)

    naive_start_datetime = Timex.to_naive_datetime(start_datetime)
    naive_end_datetime = Timex.to_naive_datetime(end_datetime)

    monitor_events = if Timex.after?(naive_start_datetime, monitor.inserted_at) do
      # The monitor was added to the account during this timeframe. Pull the accounts events
      MonitorEvent.list_events(account_id, monitor.logical_name, naive_start_datetime, naive_end_datetime)
    else
      # The monitor was not added to the account during this timeframe. Use SHARED events
      MonitorEvent.list_events(Domain.Helpers.shared_account_id(), monitor.logical_name, naive_start_datetime, naive_end_datetime)
    end

    status_page_events = StatusPage.component_changes(Domain.Helpers.shared_account_id(), monitor.logical_name, naive_start_datetime, naive_end_datetime)

    events = (monitor_events ++ status_page_events)
    |> Enum.sort(fn a, b -> NaiveDateTime.compare(get_datetime(a), get_datetime(b)) in [:lt, :eq] end)

    assigns =
      %{
        timeline_events: events,
        datetime: datetime,
        checks: checks,
        start_time_string: format_timeline_hover_datetime(start_datetime),
        end_time_string: format_timeline_hover_datetime(end_datetime),
        status_page_icon: status_page_icon
      }
    ~H"""

    <div class="bg-black text-white h-8">
      <div class="flex flex-row text-sm align-middle pt-1 pl-2 pr-2 font-bold">
        <span class="">From <%= @start_time_string %> to <%= @end_time_string %> <%= @datetime.zone_abbr %></span>
        <div class="flex-grow text-right" id="close_monitor_timeline"><a href="#">X</a></div>
      </div>
    </div>
    <div class="bg-white dark:bg-gray-800 overflow-y-auto h-36 flex flex-col p-5 text-sm">
      <%= for event <- @timeline_events do %>
        <div class="timeline-entry">
          <div class="flex flex-row mb-2">
            <div class="text-muted"><%= Timex.format!(Helpers.datetime_to_tz(get_datetime(event), @datetime.time_zone), "{h24}:{m}") %></div>
            <div class={"#{get_event_state(event)} w-1 ml-2"}></div>
            <div class="flex flex-col sm:flex-row w-full">
              <div class="text-black dark:text-white ml-2"><%= get_check_name(event, @checks, @status_page_icon) %></div>
              <div class="text-black flex-grow ml-2 sm:text-right"><span class="pill pill-solid-outline"><%= get_instance_name(event) %></span></div>
            </div>
          </div>
        </div>
      <% end %>
      <%= if length(@timeline_events) == 0 do %>
        No events found from <%= @start_time_string %> to <%= @end_time_string %> <%= @datetime.zone_abbr %>
      <% end %>
    </div>
    <div class="bg-white dark:bg-gray-800 text-right text-bright-green text-sm pr-2 pl-2">
      <a phx-click="start-configuring" href="#" class="ml-2 text-green-bright underline" phx-target="#view_component">Adjust Thresholds</a>
    </div>
    """
  end

  defp format_timeline_hover_datetime(dt), do: Timex.format!(dt, "%d %b, %H:%M", :strftime)

  defp format_date(datetime) do
    DateTime.to_date(datetime)
    |> Date.to_string()
  end

  def skip_render(assigns) do
    ~H"""
    <div phx-hook="MonitorTimeline" id="monitor_timeline"></div>
    """
  end

  defp provider_image({:svg, icon}) do
    assigns = %{icon: icon}
    ~H"""
    <%= svg_image(@icon, class: "w-7 h-7 inline dark:hidden") %>
    <%= svg_image("#{@icon}-dark", class: "w-7 h-7 hidden dark:inline") %>
    """
  end

  defp provider_image({:png, id}) do
    assigns = %{id: id}
    ~H"""
    <img src={monitor_image_url(@id)} class="w-7 h-7 inline" />
    """
  end

  defp assign_monitor_event_statuses(%{assigns: assigns} = socket) do
    monitor_added_time = assigns.monitor.inserted_at
    timeline_start_time = assigns.timeline_datetimes |> hd() |> Timex.to_naive_datetime()

    event_states = if Timex.after?(monitor_added_time, timeline_start_time) do
      # Changes from SHARED from timeline start to monitor added
      shared_changes = Backend.Projections.Dbpa.MonitorEvent.list_events(Domain.Helpers.shared_account_id(), assigns.monitor.logical_name, timeline_start_time, monitor_added_time)
      |> Enum.map(fn event ->
        %{
          date: event.start_time,
          state: event.state
        }
      end)


      # Changes from account from monitor added to now
      account_changes = Backend.Projections.Dbpa.MonitorEvent.list_events(assigns.account_id, assigns.monitor.logical_name, monitor_added_time, Timex.now)
      |> Enum.map(fn event ->
        %{
          date: event.start_time,
          state: event.state
        }
      end)

      shared_changes ++ account_changes
    else
      # Changes from account from timeline start to now
      Backend.Projections.Dbpa.MonitorEvent.list_events(assigns.account_id, assigns.monitor.logical_name, timeline_start_time, Timex.now)
      |> Enum.map(fn event ->
        %{
          date: event.start_time,
          state: event.state
        }
      end)
    end
    |> Enum.map(fn event ->
      %{
        date: Helpers.datetime_to_tz(event.date, socket.assigns.timezone),
        state: event.state
      }
    end)

    assign(socket, event_states: event_states)
  end

  defp assign_status_page_statuses(%{assigns: assigns} = socket) do
    status_page_statuses = Projections.status_page_changes(assigns.monitor.logical_name, "90day")
    |> Enum.map(fn change ->
      %{
        date: Helpers.datetime_to_tz(change.changed_at, socket.assigns.timezone),
        state: Projections.status_page_status_to_snapshot_state(change.status)
      }
    end)
    |> Enum.reject(& &1.state == :unknown)

    socket = assign(socket, status_page_statuses: status_page_statuses)
    if length(status_page_statuses) == Projections.status_page_limit()  do
      put_flash(socket, :info, "We have more than #{Projections.status_page_limit()} status page changes for this time period, and therefore are not able to show them all.")
    else
      socket
    end
  end

  def fill_state_changes(changes, timeline_datetimes, timeframe) do
    changes_by_datetime = changes
    |> group_state_changes(timeframe)
    |> make_map_of_worst_and_final_state_by_date()

    Enum.map(timeline_datetimes, fn dt -> changes_by_datetime[dt] end)
    |> fill_empty_state_changes_by_previous()
    |> Enum.map(fn %{worst: worst} -> worst end)
  end

  def group_state_changes(state_changes, timeframe)

  def group_state_changes(state_changes, 3) do
    Enum.group_by(state_changes, fn change ->
      date = DateTime.truncate(change.date, :second)
      %DateTime{date | minute: 0, second: 0}
    end)
  end

  def group_state_changes(state_changes, 30) do
    Enum.group_by(state_changes, fn change ->
      date = DateTime.truncate(change.date, :second)
      new_hour = floor(date.hour / 8) * 8
      %DateTime{date | hour: new_hour, minute: 0, second: 0}
    end)
  end

  def group_state_changes(state_changes, 90) do
    Enum.group_by(state_changes, fn change ->
      date = DateTime.truncate(change.date, :second)
      %DateTime{date | hour: 0, minute: 0, second: 0}
    end)
  end

  def make_map_of_worst_and_final_state_by_date(grouped_state_changes) do

    Enum.into(grouped_state_changes, %{}, fn {date, state_changes} ->
      worst =
        state_changes
        |> Enum.map(& &1.state)
        |> Enum.reduce(&Snapshot.get_worst_state/2)

      final =
        state_changes
        |> Enum.max_by(& &1.date, DateTime)
        |> Map.get(:state)

      {date, %{worst: worst, final: final}}
    end)
  end

  def fill_empty_state_changes_by_previous(worst_and_final_states) do
    [first | rest] = worst_and_final_states

    # If the first element is nil, set a default value
    first = if is_nil(first) do
      %{final: Snapshot.state_up(), worst: Snapshot.state_up()}
    else
      first
    end

    worst_and_final_states = [first | rest]

    Enum.scan(worst_and_final_states, fn current, prev ->
      state = if is_nil(current) do
        %{worst: prev.final, final: prev.final}
      else
        current
      end

      %{state | worst: Snapshot.get_worst_state(state.final, state.worst)}
    end)
  end

  @doc """
  Creates a datetime based on the given timeframe
  For example:
  ```elixir
    timeframe = 3 days, date_range = ~D[2022-03-22] to ~D[2022-03-25], tz = "Etc/UTC"
    Result: [~U[2022-03-22 00:00:00Z], ~U[2022-03-22 00:01:00Z], ..., ~U[2022-03-25 23:00:00Z]]

    timeframe = 30 days, date_range = ~D[2022-03-22] to ~D[2022-04-22], tz = "Etc/UTC"
    Result: [~U[2022-03-23 00:00:00Z], ~U[2022-03-23 08:00:00Z], ~U[2022-02-23 16:00:00Z], ..., ~U[2022-04-22 23:00:00Z]]
  ```
  """
  def make_timeline_datetimes(date_range, exact_end_datetime, tz, timeframe) do
    Enum.flat_map(date_range, fn day ->
      for hour <- @timeframe_configs[timeframe].hour_range do
        Timex.to_datetime(day, tz)
        |> Timex.shift(hours: hour)
      end
    end)
    |> Enum.filter(& DateTime.compare(exact_end_datetime, &1) == :gt)
  end

  defp get_check_name(%MonitorEvent{check_logical_name: check_logical_name}, checks, _icon) do
    checks
    |> Map.get(check_logical_name, check_logical_name)
  end
  defp get_check_name(%StatusPage.ComponentChange{} = spcc, _checks, icon) do
    assigns = %{
      status: spcc.status,
      component_name: spcc.component_name,
      icon: icon
    }
    ~H"""
    <%= provider_image(@icon) %>
    Vendor status page: <%= @status %> for <%= @component_name %>
    """
  end

  defp get_event_state(%MonitorEvent{state: _state, is_valid: false}), do: get_event_state(:up)
  defp get_event_state(%MonitorEvent{state: state}), do: get_event_state(state)
  defp get_event_state(%StatusPage.ComponentChange{state: state}), do: get_event_state(state)
  defp get_event_state(state) do
    case state do
      :up -> "bg-healthy"
      :degraded -> "bg-degraded"
      :issues -> "bg-issues"
      :down -> "bg-down"
    end
  end

  defp get_instance_name(%MonitorEvent{instance_name: name}), do: name
  defp get_instance_name(%StatusPage.ComponentChange{instance: name}), do: name

  def get_datetime(%MonitorEvent{start_time: dt}), do: dt
  def get_datetime(%StatusPage.ComponentChange{changed_at: dt}), do: dt

  defp timeline_class(state) do
    up = Snapshot.state_up()
    degraded = Snapshot.state_degraded()
    issues = Snapshot.state_issues()
    down = Snapshot.state_down()

    case state do
      ^up -> "bg-healthy"
      ^degraded -> "bg-degraded"
      ^issues -> "bg-issues"
      ^down -> "bg-down"
    end
  end

  def fade_class(false), do: ""
  def fade_class(true), do: "bg-opacity-50"
end
