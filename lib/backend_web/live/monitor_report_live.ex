defmodule BackendWeb.MonitorReportLive do
  use BackendWeb, :live_view

  @empty_snapshot %Backend.Projections.Dbpa.Snapshot.Snapshot{
      check_details: []
  }

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(
        account: Backend.Projections.get_account(session["current_user"].account_id, [:original_user]),
        monitor: %Backend.Projections.Dbpa.Monitor{},
        checks_to_display: %{},
        snapshot: @empty_snapshot,
        errors_map: %{},
        baseline_errors_map: %{},
        page_title: "Loading...",
        logical_name: "",
        status_page_changes: %{changes: []},
        checks: [],
        baseline_checks: [],
        current_instance_name: "all",
        current_timespan: "week",
        current_aggregate: "MAX",
        average_latencies: [],
        success_rates: [],
        events: [])
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    if connected?(socket) do
      # Load and assign all fixed-for-this-session data
      monitor_logical_name = params["monitor"]
      account_id = account_id(socket)
      monitor = Backend.Projections.monitor_with_checks_and_instances(account_id, monitor_logical_name)
      snapshot = Backend.RealTimeAnalytics.get_snapshot_or_nil(account_id, monitor_logical_name)
      snapshot = snapshot || @empty_snapshot
      socket =
        assign(socket,
          monitor: monitor,
          logical_name: monitor_logical_name,
          snapshot: snapshot,
          page_title: "#{monitor.name} Report"
        )

      # Load data that changes with the dropdowns.
      socket = load_variable_data(socket)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Note: this can probably be optimized by passing in what changed.
  defp load_variable_data(socket, what_changed? \\ :everything) do
    account_id = account_id(socket)
    monitor_logical_name = socket.assigns.logical_name
    current_timespan = socket.assigns.current_timespan

    instance_matches = fn
      "all", _ -> true
      i, i -> true
      _, _ -> false
    end
    checks_to_display = socket.assigns.snapshot.check_details
    |> Enum.filter(fn details ->
      instance_matches.(socket.assigns.current_instance_name, details.instance)
    end)
    |> Enum.map(fn
      details -> {details.check_id, details.name}
    end)
    |> Map.new()

    # We fire off a bunch of loads in separate processes and then load the
    # telemetry report.
    {errors_map, baseline_errors_map, status_page_changes, events} =
      if what_changed? in [:everything, :timespan] do
        {Task.async(fn -> Backend.Projections.monitor_errors(account_id, monitor_logical_name, current_timespan) end),
         Task.async(fn -> Backend.Projections.monitor_errors("SHARED", monitor_logical_name, current_timespan) end),
         Task.async(fn -> Backend.Projections.status_page_changes(monitor_logical_name, current_timespan) end),
         Task.async(fn -> Backend.Projections.monitor_events(account_id, monitor_logical_name, current_timespan) end)}
      else
          {socket.assigns.errors_map,
           socket.assigns.baseline_errors_map,
           socket.assigns.status_page_changes,
           socket.assigns.events}
      end

    telemetry_report = Backend.Telemetry.get_telemetry_report(monitor_logical_name,
      socket.assigns.current_instance_name,
      socket.assigns.current_timespan,
      socket.assigns.current_aggregate,
      socket.assigns.current_user.account_id)

    maybe_wait = fn
      t = %Task{} -> Task.await(t)
      x -> x
    end

    socket =
      assign(socket,
        checks_to_display: checks_to_display,
        errors_map: maybe_wait.(errors_map),
        baseline_errors_map: maybe_wait.(baseline_errors_map),
        status_page_changes: maybe_wait.(status_page_changes),
        checks: telemetry_report.checks,
        baseline_checks: telemetry_report.baseline_checks,
        check_aggregates: telemetry_report.check_aggregates,
        baseline_check_aggregates: telemetry_report.baseline_check_aggregates,
        events: maybe_wait.(events)
      )

    socket
      |> setup_average_latencies()
      |> setup_success_rates()
  end

  defp setup_average_latencies(socket) do
    values =
      for {logical_name, name} <- socket.assigns.checks_to_display do
        # TODO get rid of all the looping, return nicer data structures from telemetry
        baseline_aggregate =
          Enum.find(socket.assigns.baseline_check_aggregates, %{}, fn blc ->
            blc.check_id == logical_name
          end)

        check_aggregate = Enum.find(socket.assigns.check_aggregates, %{}, fn c ->
          c.check_id == logical_name
        end)

        value_ms = Map.get(check_aggregate, :mean, 0)
        baseline_ms = Map.get(baseline_aggregate, :mean, 0)
        {formatted_value, value_suffix} = BackendWeb.Helpers.formatted_duration(value_ms)
        {formatted_baseline, baseline_suffix} = BackendWeb.Helpers.formatted_duration(baseline_ms)

        %{
          check_id: logical_name,
          title: name,
          value: value_ms,
          formatted_value: formatted_value,
          value_suffix: value_suffix,
          baseline: baseline_ms,
          formatted_baseline: formatted_baseline,
          baseline_suffix: baseline_suffix
        }
      end

    assign(socket, average_latencies: values)
  end

  defp setup_success_rates(socket) do
    values =
      for {logical_name, name} <- socket.assigns.checks_to_display do
        count_in_map = fn map -> Enum.count(Map.get(map, logical_name, [])) end

        error_count = count_in_map.(socket.assigns.errors_map)
        baseline_error_count = count_in_map.(socket.assigns.baseline_errors_map)
        success_count = count_in_map.(socket.assigns.checks)
        baseline_success_count = count_in_map.(socket.assigns.baseline_checks)

        success_rate = calc_rate(success_count, error_count)
        baseline_success_rate = calc_rate(baseline_success_count, baseline_error_count)

        %{
          check_id: logical_name,
          value: success_rate,
          baseline: baseline_success_rate,
          title: name,
          suffix: "%"
        }
      end

    assign(socket, success_rates: values)
  end

  def calc_rate(successes, errors) do
    case (successes + errors) do
      0 -> nil
      sum -> (successes / sum) * 100
    end
  end

  def image_url(nil), do: ""
  def image_url(monitor) do
    monitor_image_url(monitor.logical_name)
  end

  # Mock Vue/Nuxt's "$t" for now
  def t(arg), do: BackendWeb.I18n.str(arg)

  def instance_names(snapshot) do
    found =
      snapshot.check_details
      |> Enum.map(& &1.instance)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn r -> {"#{r} region", r} end)

    [{"All regions", "all"} | found]
  end

  def get_telemetry_data(checks_to_display, checks, baseline_checks) do
    for {logical_name, name} <- checks_to_display do
      check_telemetry = checks[logical_name] || []
      baseline_telemetry = baseline_checks[logical_name] || []
      %{
        check_id: logical_name,
        name: name,
        check_telemetry: check_telemetry,
        baseline_telemetry: baseline_telemetry
      }
    end
  end

  def has_private_checks(monitor) do
    Ecto.assoc_loaded?(monitor.checks) && Enum.any?(monitor.checks, &(&1.is_private))
  end

  def is_private_check(monitor, check) do
    Ecto.assoc_loaded?(monitor.checks) && Enum.any?(monitor.checks, fn c ->
      c.logical_name == check.check_id and c.is_private
    end)
  end

  def get_telemetry_for_graph(telemetry) do
    telemetry
    |> Enum.map(fn x -> %{x: Map.get(x, :time)
                             |> DateTime.from_naive!("UTC")
                             |> DateTime.to_iso8601(),
                          y: Map.get(x, :value)} end)
  end


  def error_annotations(check, timespan, check_errors, baseline_errors) do
    grouping_msecs =
      with {_, _, grouping_secs} <- Backend.Telemetry.timespan_to_timescale(timespan) do
        grouping_secs * 1_000
      end

    datetime_to_ms = fn n_dt = %NaiveDateTime{} ->
        # We interpret timezoneless stuff as UTC
        n_dt
        |> DateTime.from_naive!("UTC")
        |> DateTime.to_unix(:millisecond)
    end

    check_errors = Map.get(check_errors, check.check_id, [])
    baseline_errors = Map.get(baseline_errors, check.check_id, [])

    # Convert the errors to a histogram of error counts and then
    # to what the graphing library needs
    error_histo =
      (check_errors ++ baseline_errors)
      |> Enum.map(fn e -> datetime_to_ms.(e.time) end)
      |> Enum.group_by(fn t_ms ->
        Integer.floor_div(t_ms, grouping_msecs) * grouping_msecs
      end)
      |> Enum.map(fn {start_ms, elems} ->
        {start_ms, Enum.count(elems)}
      end)

    danger_400 = %{variant: "danger", shade: "400"}

    Enum.map(error_histo, fn {start_ms, count} ->
      %{
        x: start_ms,
        x2: start_ms + grouping_msecs,
        borderColor: danger_400,
        fillColor: danger_400,
        opacity: 0.5,
        label: %{
          text: Integer.to_string(count),
          orientation: 'horizontal',
          borderColor: danger_400,
          offsetX: 10,
          style: %{
            background: danger_400,
            color: "white",
          }
        }
      }
    end)
  end

  def entries(timeseries, key) do
    entries = timeseries.mergedSeries.entries
    Enum.map(entries, fn e -> Map.get(e, key) end)
  end

  @impl true
  def handle_event("select-instance", %{"new-instance" => new_instance}, socket) do
    socket = socket
    |> assign(current_instance_name: new_instance)
    |> load_variable_data(:instance)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-timespan", %{"new-timespan" => new_timespan}, socket) do
    socket = socket
    |> assign(current_timespan: new_timespan)
    |> load_variable_data(:timespan)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-aggregate", %{"new-aggregate" => new_aggregate}, socket) do
    socket = socket
    |> assign(current_aggregate: new_aggregate)
    |> load_variable_data(:aggregate)

    {:noreply, socket}
  end

  @impl true
  def handle_event(evt, params, socket) do
    IO.puts("Unhandled event '#{inspect(evt)}' with #{inspect(params)}")
    IO.puts("Socket: #{inspect(socket)}")
    {:noreply, socket}
  end
end
