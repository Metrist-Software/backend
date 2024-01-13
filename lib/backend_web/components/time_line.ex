defmodule BackendWeb.Components.TimeLine do
  use BackendWeb, :live_component

  def mount(socket) do
    {:ok,
     assign(socket,
       days: [],
       changes: %{},
       events: %{},
       timespan: "week",
       name: ""
     )}
  end

  def update(assigns, socket) do
    if connected?(socket) do
      days = days_for_timespan(assigns.timespan)
      {changes, events} =
        group_by_day(assigns.changes, assigns.events)

      {:ok,
       assign(socket,
         days: days,
         changes: changes,
         events: events,
         name: assigns.monitor_name,
         timespan: assigns.timespan
       )}
    else
      {:ok, socket}
    end
  end

  def days_for_timespan("week") do
    days_for_timespan(7)
  end
  def days_for_timespan("month") do
    days_for_timespan(30)
  end
  def days_for_timespan(other) when is_binary(other) do
    days_for_timespan(1)
  end
  def days_for_timespan(days_back) do
    today = Date.utc_today()
    start = Date.add(today, -days_back)
    for i <- days_back..0 do
      Date.add(start, i)
    end
  end

  defp group_by_day(changes, events) do
    changes_by_day = Enum.group_by(changes, fn change ->
      NaiveDateTime.to_date(change.changed_at)
    end)

    events_by_day = Enum.group_by(events, fn event ->
      NaiveDateTime.to_date(event.start_time)
    end)

    {changes_by_day, events_by_day}
  end

  defp group_by_minute(today_changes, today_events) do
    changes_by_minute = Enum.group_by(today_changes || [], &format_time(&1.changed_at))
    events_by_minute = Enum.group_by(today_events || [], &format_time(&1.start_time))

    all_minutes = MapSet.new(Map.keys(changes_by_minute) ++ Map.keys(events_by_minute))
    |> MapSet.to_list()
    |> Enum.sort(&(&1 > &2))

    {all_minutes, changes_by_minute, events_by_minute}
  end

  # Format the hh:mm part of a datetime as a string. We have to support (like
  # in the grouping) strings from GraphQL and NaiveDateTime from PostgreSQL
  defp format_time(iso8601_string) when is_binary(iso8601_string) do
    {:ok, dt, 0} = DateTime.from_iso8601(iso8601_string)
    dt
    |> DateTime.to_time()
    |> format_time()
  end
  defp format_time(n_dt = %NaiveDateTime{}) do
    n_dt
    |> NaiveDateTime.to_time()
    |> format_time()
  end
  defp format_time(t = %Time{}) do
    t
    |> Time.to_string()
    |> String.slice(0, 5)
  end

  @days ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  @months ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  def format_date(date) do
    dow = Enum.at(@days, Date.day_of_week(date))
    dom = String.pad_leading("#{date.day}", 2, "0")
    mon = Enum.at(@months, date.month)
    "#{dow} - #{mon} #{dom}, #{date.year} UTC"
  end

  def show_change(_changes, _empty = true), do: nothing_reported()
  def show_change([], _), do: empty_entry()
  def show_change([change | _], _) do
    # TODO - what if we have two entries at the same minute?
    timeline_template(%{
          state: change.status,
          time: format_time(change.changed_at),
          message: change.component_name
                      })
  end

  def show_event(_events, _empty = true), do: nothing_reported()
  def show_event([], _), do: empty_entry()
  def show_event([event | _], _) do
    timeline_template(%{
          state: event.state,
          time: format_time(event.start_time),
          message: event.message
                      })
  end

  defp maybe_downcase(val) when is_binary(val), do: String.downcase(val)
  defp maybe_downcase(val), do: val

  def timeline_template(event) do
    border = case maybe_downcase(event.state) do
               "up" -> "green"
               0 -> "green"
               "operational" -> "green"
               "degraded" -> "warning"
               1 -> "warning"
               "down" -> "danger"
               2 -> "danger"
               "degraded_performance" -> "warning"
               "under_maintenance" -> "warning"
               _ -> "gray"
             end
    assigns = %{border: border, time: event.time, message: event.message}
    ~H"""
    <div class="box overflow-hidden">
      <div class={"py-3 px-4 border-l-4 border-#{@border}-500"}>
        <header>
          <h3 class="inline-block">
            <span class="inline-block mr-2 text-sm text-muted" >
              <%= @time %> UTC
            </span>

            <%= @message %>
          </h3>
        </header>
      </div>
    </div>
    """
  end

  def empty_entry(assigns \\ %{}) do
    ~H"""
    <div class="overflow-hidden">
    </div>
    """
  end

  def nothing_reported(assigns \\ %{}) do
    ~H"""
    <div class="overflow-hidden text-muted text-center">
    Nothing reported
    </div>
    """

  end
end
