  # ADD MONitor from admin tool
# update analyzer config
# mci_process.ex reset_with
# rta admin tool

defmodule BackendWeb.Admin.Utilities.SwitchTestMonitorState do
  use BackendWeb, :live_view

  require Logger
  alias Domain.Account.Commands, as: AccountCmds
  alias Domain.Monitor.Commands, as: MonitorCmds

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Switch Test Monitor State",
        monitor_id: "testmonitor",
        name: "testname",
        monitor_aggregate_id: Backend.Projections.construct_monitor_root_aggregate_id(socket.assigns.current_user.account_id, "testmonitor"),
        host_name: "host_name",
        has_test_monitor?: test_monitor_exists?(socket.assigns.current_user.account_id)
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("create_monitor", _, socket) do
    monitor_id = socket.assigns.monitor_id
    name = socket.assigns.name
    monitor_aggregate_id = socket.assigns.monitor_aggregate_id
    host_name = socket.assigns.host_name
    account_id = socket.assigns.current_user.account_id

    report_time = NaiveDateTime.utc_now()

    cmds = [
      %AccountCmds.AddMonitor{
        id: account_id,
        logical_name: monitor_id,
        name: name,
        default_degraded_threshold: 1.0,
        instances: [],
        check_configs: []
      },
      %MonitorCmds.Create{
        id: monitor_aggregate_id,
        monitor_logical_name: monitor_id,
        name: name,
        account_id: account_id
      },
      %MonitorCmds.AddTag{id: monitor_aggregate_id, tag: "other"},
      %MonitorCmds.AddTelemetry{
        id: monitor_aggregate_id,
        account_id: account_id,
        monitor_logical_name: monitor_id,
        instance_name: host_name,
        is_private: false,
        value: 5,
        check_logical_name: "testcheck1",
        report_time: report_time
      },
      %MonitorCmds.AddTelemetry{
        id: monitor_aggregate_id,
        account_id: account_id,
        monitor_logical_name: monitor_id,
        instance_name: host_name,
        is_private: false,
        value: 5,
        check_logical_name: "testcheck2",
        report_time: report_time
      }
    ]
    dispatch_cmds(cmds, socket, false)
    {:noreply, socket |> assign(has_test_monitor?: test_monitor_exists?(account_id))}
  end

  def handle_event("remove_monitor", _, socket) do
    has_test_monitor? =
      case BackendWeb.Helpers.dispatch_with_auth_check(socket, %AccountCmds.ChooseMonitors{
        id: socket.assigns.current_user.account_id,
        user_id: socket.assigns.current_user.id,
        add_monitors: [],
        remove_monitors: [socket.assigns.monitor_id]
      }) do
        {:error, _} -> true
        _ ->
          Backend.RealTimeAnalytics.Analysis.remove_config(
            socket.assigns.current_user.account_id,
            socket.assigns.monitor_id
          )
          false
      end
    {:noreply, socket |> assign(has_test_monitor?: has_test_monitor?)}
  end

  def handle_event("down_check", %{"name" => check_name}, socket) do
    dispatch_cmds([
      %MonitorCmds.AddError{
        id: socket.assigns.monitor_aggregate_id,
        error_id: Domain.Id.new(),
        account_id: socket.assigns.current_user.account_id,
        monitor_logical_name: socket.assigns.monitor_id,
        instance_name: socket.assigns.host_name,
        is_private: false,
        message: "added an error",
        report_time: NaiveDateTime.utc_now(),
        check_logical_name: check_name
      },
    ], socket)
    {:noreply, socket}
  end

  def handle_event("up_check", %{"name" => check_name}, socket) do
    dispatch_cmds([
      %MonitorCmds.AddTelemetry{
        id: socket.assigns.monitor_aggregate_id,
        account_id: socket.assigns.current_user.account_id,
        monitor_logical_name: socket.assigns.monitor_id,
        instance_name: socket.assigns.host_name,
        is_private: false,
        value: 1,
        check_logical_name: check_name,
        report_time: NaiveDateTime.utc_now()
      },
    ], socket)
    {:noreply, socket}
  end

  def handle_event("degrade_monitor", %{"name" => check_name}, socket) do
    mcis_averages = Backend.RealTimeAnalytics.SwarmSupervisor.get_all_mci_processes_for_account_and_monitor(
      socket.assigns.current_user.account_id,
      "testmonitor"
      )
      |> Enum.reduce(%{}, fn pid, acc ->
        state = :sys.get_state(pid)
        {_id, _monitor, check_name, _instance} = state.mci
        Map.put(acc, check_name, Backend.RealTimeAnalytics.MCIProcess.average(pid))
      end)

    # calculate 10% higher than average value to get over the 1% degraded threshold
    value = mcis_averages |> Map.get(check_name)
    value = Float.ceil(value * 1.1)

    dispatch_cmds([
      %MonitorCmds.AddTelemetry{
        id: socket.assigns.monitor_aggregate_id,
        account_id: socket.assigns.current_user.account_id,
        monitor_logical_name: socket.assigns.monitor_id,
        instance_name: socket.assigns.host_name,
        is_private: false,
        value: value,
        check_logical_name: check_name,
        report_time: NaiveDateTime.utc_now()
      }
    ], socket)
    {:noreply, socket}
  end

  def handle_event("update_sp", %{"state" => state}, socket) do
    monitor_id = socket.assigns.monitor_id
    status_page = Backend.Projections.status_page_by_name(monitor_id)

    status_page_id = case status_page do
      nil ->
        id = Domain.Id.new()
        dispatch_cmds([%Domain.StatusPage.Commands.Create{id: id, page: monitor_id}], socket)
        id
      status_page ->
        status_page.id
    end

    dispatch_cmds([
      %Domain.StatusPage.Commands.ProcessObservations{
        id: status_page_id,
        page: monitor_id,
        observations: [
          %Domain.StatusPage.Commands.Observation{
            changed_at: NaiveDateTime.utc_now(),
            component: "test_component",
            instance: nil,
            status: state,
            state: String.to_existing_atom(state)
          }
        ]
      }
    ], socket)

    {:noreply, socket}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <p>Monitor Actions</p>
    <.button disabled={@has_test_monitor?} label="Create Test monitor_id" phx-click="create_monitor" />
    <.button disabled={not @has_test_monitor?} label="Remove Test monitor_id" phx-click="remove_monitor" />

    <p>check1 Actions</p>
    <.button disabled={not @has_test_monitor?} label="Down testcheck1" phx-click="down_check" phx-value-name="testcheck1" />
    <.button disabled={not @has_test_monitor?} label="Up testcheck1" phx-click="up_check" phx-value-name="testcheck1" />
    <.button disabled={not @has_test_monitor?} label="Degrade testcheck1" phx-click="degrade_monitor" phx-value-name="testcheck1" />

    <p>check2 Actions</p>
    <.button disabled={not @has_test_monitor?} label="Down testcheck2" phx-click="down_check" phx-value-name="testcheck2" />
    <.button disabled={not @has_test_monitor?} label="Up testcheck2" phx-click="up_check" phx-value-name="testcheck2" />
    <.button disabled={not @has_test_monitor?} label="Degrade testcheck2" phx-click="degrade_monitor" phx-value-name="testcheck2" />

    <p>Status Page Actions</p>
    <.button disabled={not @has_test_monitor?} label="Down component"     phx-click="update_sp" phx-value-state="down" />
    <.button disabled={not @has_test_monitor?} label="Up component"      phx-click="update_sp" phx-value-state="up" />
    <.button disabled={not @has_test_monitor?} label="Degrade component" phx-click="update_sp" phx-value-state="degraded" />
    """
  end

  defp test_monitor_exists?(account_id) do
    Enum.member?(Enum.map(Backend.Projections.list_monitors(account_id), fn monitor_id ->
      monitor_id.name end),
    "testname")
  end

  defp dispatch_cmds(cmds, socket, reset_analyzer_config \\ true) do
    cmds =
      if reset_analyzer_config do
        # In most cases we want to reset analyzer config. Only exception is when we are first creating the monitor_id as there's nothing to update yet
        analyzer_config_update = %MonitorCmds.UpdateAnalyzerConfig{
          id: socket.assigns.monitor_aggregate_id,
          default_degraded_threshold: 1.0,
          instances: [],
          check_configs: [],
          default_degraded_down_count: 1,
          default_degraded_up_count: 1,
          default_error_down_count: 1,
          default_error_up_count: 1
        }

        [ analyzer_config_update | cmds ]
      else
        cmds
      end

    Enum.each(cmds, fn cmd -> BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) end)
  end

end
