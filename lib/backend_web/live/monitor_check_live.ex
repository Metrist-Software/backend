defmodule BackendWeb.MonitorCheckLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(
        account: Backend.Projections.get_account(session["current_user"].account_id, [:original_user]),
        monitor: "",
        check: "",
        check_name: "",
        page_title: "Loading...",
        editing: false,
        current_timespan: "week",
        current_aggregate: "MAX",
        instances: [],
        baseline_telemetry: [],
        account_telemetry: [])
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    if connected?(socket) do
      check = Backend.Projections.get_check(Domain.Helpers.shared_account_id, params["monitor"], params["check"])
        || Backend.Projections.get_check(socket.assigns.current_user.account_id, params["monitor"], params["check"])

      snapshot = Backend.RealTimeAnalytics.get_snapshot_or_nil(socket.assigns.current_user.account_id, params["monitor"])

      {:noreply, socket
        |> assign(monitor: params["monitor"])
        |> do_handle_params(check, snapshot)}
    else
      {:noreply, socket}
    end
  end

  defp do_handle_params(socket, nil, _snapshot), do: put_flash(socket, :error, "The requested check could not be found.")
  defp do_handle_params(socket, _check, nil), do: put_flash(socket, :info, "No data available for this check yet.")
  defp do_handle_params(socket, check, snapshot) do
    instances = snapshot.check_details
      |> Enum.filter(&(&1.check_id == check.logical_name))
      |> Enum.map(&(&1.instance))

    socket
      |> assign(
          check: check.logical_name,
          check_name: check.name,
          page_title: "#{check.name} Check",
          instances: instances)
      |> update_telemetry()
  end

  @impl true
  def handle_event("toggle-edit", _, socket) do
    {:noreply, assign(socket, editing: !socket.assigns.editing)}
  end

  def handle_event("edit-submit", %{"name" => name}, socket) do
    cmd = %Domain.Monitor.Commands.UpdateCheckName{
      id: Backend.Projections.construct_monitor_root_aggregate_id(Domain.Helpers.shared_account_id, socket.assigns.monitor),
      logical_name: socket.assigns.check,
      name: name
    }

    case BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) do
      {:error, _} -> {:noreply, socket}
      _ ->
        {:noreply, assign(socket,
          editing: false,
          check_name: name,
          page_title: "#{name} Check")}
    end
  end

  def handle_event("select-timespan", %{"new-timespan" => ts}, socket) do
    {:noreply, socket |> assign(current_timespan: ts) |> update_telemetry()}
  end

  def handle_event("select-aggregate", %{"new-aggregate" => ag}, socket) do
    {:noreply, socket |> assign(current_aggregate: ag) |> update_telemetry()}
  end

  def format_telemetry_for_graph(telemetry) do
    telemetry
      |> Enum.map(fn telem -> %{x: telem.time
                                    |> DateTime.from_naive!("UTC")
                                    |> DateTime.to_iso8601(),
                                y: telem.value} end)
  end

  def update_telemetry(socket) do
    baseline_telemetry = Backend.Telemetry.get_check_telemetry(
      socket.assigns.monitor,
      socket.assigns.check,
      socket.assigns.current_timespan,
      socket.assigns.current_aggregate,
      Domain.Helpers.shared_account_id)
    |> Enum.group_by(&(&1.instance_id))
    |> Enum.map(fn ({instance, telemetry}) -> {instance, format_telemetry_for_graph(telemetry)} end)
    |> Enum.into(%{})

    account_telemetry = Backend.Telemetry.get_check_telemetry(
      socket.assigns.monitor,
      socket.assigns.check,
      socket.assigns.current_timespan,
      socket.assigns.current_aggregate,
      BackendWeb.Helpers.account_id(socket))
    |> Enum.group_by(&(&1.instance_id))
    |> Enum.map(fn ({instance, telemetry}) -> {instance, format_telemetry_for_graph(telemetry)} end)
    |> Enum.into(%{})

    assign(socket, baseline_telemetry: baseline_telemetry, account_telemetry: account_telemetry)
  end

  def t(arg), do: BackendWeb.I18n.str(arg)
end
