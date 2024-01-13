defmodule Backend.RealTimeAnalytics.Loader do
  @moduledoc """
  This process is responsible for loading data for existing monitors on startup and
  seeding new monitors during run time. It is started under Horde so will be a cluster-wide
  singleton. It starts per monitor/check/instance processes under Horde as well.

  The loader will also periodically check if re-initialization has been requested. This would only occur
  if an analysis process or mci process was restarted through swarm but was not initialized because of a
  network split or hard kill
  """

  require Logger
  use GenServer, restart: :transient, shutdown: 60_000
  use TypedStruct

  alias Backend.Projections.Dbpa.{ Monitor, AnalyzerConfig, MonitorEvent }
  alias Backend.RealTimeAnalytics.SwarmSupervisor

  @health_check_interval 30_000

  typedstruct module: State, enforce: true do
    field :initialized, boolean()
    field :reinit_requested, boolean(), default: false
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    Logger.info("Starting RTA loader as #{inspect(name)}")
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def request_initialization() do
    case Swarm.whereis_name(SwarmSupervisor.loader_name()) do
      :undefined ->
        Logger.warn("#{inspect self()} is requesting Loader initialization but the loader can't be found.")
      pid ->
        GenServer.cast(pid, :register_initialization_request)
        {:ok}
    end
  end

  def check_registration() do
    if Swarm.whereis_name(SwarmSupervisor.loader_name()) == self() do
      Logger.debug("Loader is registered with Swarm properly as #{inspect self()}")
      :ok
    else
      Logger.warn("""
      RTA Loader is started as pid #{inspect self()} but Swarm doesn't know it's registered. \
      Most likely cause is an error in the loader which got restarted by the supervisor \
      and not Swarm. Exiting and restarting to re-register it.
      """)
      # Swarm.register_name/2 would be great here with the existing pid, but anything registered that
      # way is ignored during topology changes. Perform a normal exit here and do the loader_startup again
      # which will end up calling Swarm.register_name/5 again to restart it and re-register it
      spawn(fn ->
        Process.sleep(500); SwarmSupervisor.do_loader_startup()
      end)
      :stop
    end
  end

  def init_mci(pid, mci, message \\ nil)
  def init_mci(_pid, {nil, _, _, _} = mci, _message), do:
    Logger.warn("Ignoring init_mci request for MCI with nil account_id #{inspect mci}")
  def init_mci(_pid, {_, nil, _, _} = mci, _message), do:
    Logger.warn("Ignoring init_mci request for MCI with nil monitor_id #{inspect mci}")
  def init_mci(_pid, {_, _, nil, _} = mci, _message), do:
    Logger.warn("Ignoring init_mci request for MCI with nil check_id #{inspect mci}")
  def init_mci(_pid, {_, _, _, nil} = mci, _message), do:
    Logger.warn("Ignoring init_mci request for MCI with nil instance_id #{inspect mci}")
  def init_mci(pid, mci, message) do
    case message do
      nil -> GenServer.cast(pid, {:init_mci, mci})
      _ -> GenServer.cast(pid, {:init_mci, mci, message})
    end
  end

  def ensure_all_started(pid, mcis) do
    for mci <- mcis do
      init_mci(pid, mci)
    end
  end

  def initialize_loader(pid) do
    GenServer.cast(pid, :initial_load)
  end

  # Server side

  @impl true
  def init(_args) do
    Logger.info("RTA Loader started and initialized as #{inspect(self())}")

    Process.flag(:trap_exit, true)

    Process.send_after(self(), :health_check, 5_000)
    {:ok, %State{ initialized: false, reinit_requested: false }}
  end

  @impl true
  def handle_cast(:register_initialization_request, state) do
    {:noreply, %State{ state | reinit_requested: true }}
  end

  def handle_cast(:initial_load, state) do
    Logger.info("RTA Loader: Loading initial state")
    # For all accounts, for all monitors, for all checks/instances...
    initial_load_all_accounts()

    Logger.info("RTA Loader: Initialization complete")
    {:noreply, %State{ state | initialized: true }}
  end

  # Attempts to start an MCI process with initial data and it's associated
  # analysis process, then sends the given message to the MCI process
  def handle_cast({:init_mci, mci, message}, state) do
    {:ok, pid} = maybe_start_mci(mci)
    GenServer.cast(pid, message)

    {:noreply, state}
  end

  def handle_cast({:init_mci, mci}, state) do
    maybe_start_mci(mci)

    {:noreply, state}
  end

  def handle_cast({:swarm, :end_handoff, newstate}, state) do
    Logger.info("RTA Loader - Received state from swarm.")
    {:noreply, %State{ newstate | initialized: state.initialized }}
  end

  def handle_cast({:swarm, :resolve_conflict, _newState}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:swarm, :die}, state) do
    {:stop, :normal, state}
  end

  def handle_info(:health_check, %State{ reinit_requested: true } = state) do
    Logger.info("RTA Loader: Reinitialization has been requested. Initializing")
    initialize_loader(self())
    Process.send_after(self(), :health_check, @health_check_interval)
    {:noreply, %State{ state | reinit_requested: false}}
  end
  def handle_info(:health_check, state) do
    case check_registration() do
      :stop ->
        {:stop, :normal, state}
      _ ->
        Process.send_after(self(), :health_check, @health_check_interval)
        {:noreply, state}
    end
  end

  defp maybe_start_mci(mci) do
    # Try to lookup the mci process to verify. If it doesn't exist at this point,
    # then we know it wasn't included in the loaders initial load and should
    # still initialize it.
    case Swarm.whereis_name(mci) do
      :undefined -> load_and_start_mci(mci)
      pid ->
        {:ok, pid}
    end
  end

  def initial_load_all_accounts() do
    for acct <- Backend.Projections.list_accounts() do
      initial_load_account(acct)
    end
  end

  def initial_load_account(account) do
    monitors = Backend.Projections.list_monitors(account.id, [:checks, :instances, :analyzer_config, :monitor_configs])

    initial_load_monitors(account, monitors)
  end

  def initial_load_monitors(account, monitors) do
    # This is all a bit implicit - active monitors are those that either have seen telemetry or errors come in,
    # and while we keep track of telemetry in `:check_last_reports`, we don't have something like that for errors.
    # For now, we take the last reports and get a projection of errors to get a full list of monitors/checks/instances.
    # Analytics only looks back an hour, so that's what we will use for errors. For checks, we will use a similar cut off
    # for check_last_reports' timestamps.

    errors = Backend.Projections.monitor_errors(account.id, nil, "hour", false)
    |> Enum.group_by(& &1.monitor_logical_name)

    telemetry = Backend.Projections.telemetry(account.id, nil, "hour")
    |> Enum.group_by(& &1.monitor_id)

    outstanding_events = Backend.Projections.outstanding_events(account.id)
    |> Enum.group_by(& &1.monitor_logical_name)

    Enum.flat_map(monitors, fn monitor ->
      Logger.debug("RTA Loader: Loading monitors for #{account.id} #{monitor.logical_name}")

      monitor_errors =  Map.get(errors, monitor.logical_name, [])
      error_cis = Enum.map(monitor_errors, &({&1.check_logical_name, &1.instance_name}))
      monitor_outstanding_events = Map.get(outstanding_events, monitor.logical_name, [])

      monitor_telemetry = Map.get(telemetry, monitor.logical_name, [])
      telemetry_cis = Enum.map(monitor_telemetry, &({&1.check_id, &1.instance_id}))

      average_cut_off = NaiveDateTime.utc_now() |> Timex.shift(weeks: -1)
      averages = Backend.Telemetry.get_aggregate_telemetry(
        average_cut_off,
        "1 hour",
        monitor.logical_name,
        :mean,
        group_by_instance: true,
        account_id: account.id)

      checks_and_instances = Enum.uniq(error_cis ++ telemetry_cis)

      mcis = Enum.map(checks_and_instances, fn {check, instance} ->
        {account.id, monitor.logical_name, check, instance}
      end)
      for mci <- mcis do
        mci_errors = filter_errors(monitor_errors, mci)
        mci_telemetry = filter_telemetry(monitor_telemetry, mci)
        mci_averages = filter_averages(averages, mci)
        start_mci(mci, monitor, mci_errors, mci_telemetry, mci_averages)
      end

      start_analysis(account.id, monitor, monitor.analyzer_config, monitor_outstanding_events)

      mcis
    end)
  end

  # Called by anything that wants to start an analysis process outside of the loader initial load
  # Does the DB work for the specific monitor needed to start analysis
  @spec load_and_start_analysis(binary(), %Monitor{}, %AnalyzerConfig{}) :: :ok
  def load_and_start_analysis(account_id, monitor, analyzer_config) do
    # Although unlikely, there could be outstanding events if this monitor was previously on the account and then removed while
    # events were outstanding.
    outstanding_events = Backend.Projections.outstanding_events(account_id, monitor.logical_name)

    start_analysis(account_id, monitor, analyzer_config, outstanding_events)
  end

  @spec start_analysis(binary, %Monitor{}, %AnalyzerConfig{}, [%MonitorEvent{}]) :: :ok
  def start_analysis(account_id, monitor, analyzer_config, outstanding_events) do
    case Backend.RealTimeAnalytics.Analysis.start_analysis(account_id, monitor.logical_name) do
      {:ok, pid} ->
        Logger.debug("RTA Loader: Got #{inspect pid} from start_analysis. Initializing.")
        Backend.RealTimeAnalytics.Analysis.initialize(pid, monitor, analyzer_config, outstanding_events)
      {:already_running, pid} ->
        Logger.debug("RTA Loader: Return from start_analysis was :already_started, initializing #{inspect pid}")
        Backend.RealTimeAnalytics.Analysis.initialize(pid, monitor, analyzer_config, outstanding_events)
      other ->
        Logger.info("RTA Loader: Failed to get pid for analysis process. Not initializing. Response was #{inspect other}")
    end

    :ok
  end

  defp load_and_start_mci(mci) do
    {account_id, monitor_id, _check_id, _instance_id} = mci
    preloads = [:checks, :instances, :analyzer_config, :monitor_configs]

    monitor = Backend.Projections.get_monitor(account_id, monitor_id, preloads)

    {errors, telemetry, averages} = load_for_mci(mci)
    start_mci(mci, monitor, errors, telemetry, averages)
  end

  def load_for_mci(mci={account_id, monitor_id, _check_id, _instance_id}) do
    errors = Backend.Projections.monitor_errors(account_id, monitor_id, "hour", false)
    |> filter_errors(mci)

    telemetry = Backend.Projections.telemetry(account_id, monitor_id, "hour")
    |> filter_telemetry(mci)

    average_cut_off = NaiveDateTime.utc_now() |> Timex.shift(weeks: -1)
    averages = Backend.Telemetry.get_aggregate_telemetry(
      average_cut_off,
      "1 hour",
      monitor_id,
      :mean,
      group_by_instance: true,
      account_id: account_id)
    |> filter_averages(mci)

    {errors, telemetry, averages}
  end

  def filter_averages(averages, {_account_id, _monitor_logical_name, check, instance}) do
    Enum.filter(averages, fn t ->
      t.instance_id == instance && t.check_id == check
    end)
  end

  def filter_errors(errors, {_account_id, _monitor_logical_name, check, instance}) do
    Enum.filter(errors, fn e ->
      e.instance_name == instance && e.check_logical_name == check
    end)
  end

  def filter_telemetry(telemetry, {_account_id, _monitor_logical_name, check, instance}) do
    Enum.filter(telemetry, fn t ->
      t.instance_id == instance && t.check_id == check
    end)
  end

  # We currently don't use monitor but that has analyzer config in case we need it.
  def start_mci(mci, _monitor, mci_errors, mci_telemetry, mci_averages) do
    Logger.debug("RTA Loader: starting/reseeding #{inspect(mci)}")
    errors = Enum.map(mci_errors, fn e ->
      {
        e.time,
        %{
          error_id: e.message,
          blocked_steps: e.blocked_steps
        }
      }
    end)
    telemetry = Enum.map(mci_telemetry, fn t -> {t.time, t.value} end)
    averages = Enum.map(mci_averages, fn t -> {t.value, t.count, t.time} end)

    pid =
      case Swarm.whereis_name(mci) do
        :undefined ->
          case Backend.RealTimeAnalytics.SwarmSupervisor.start_child(mci) do
            {:ok, pid} ->
              Backend.RealTimeAnalytics.MCIProcess.reset_with(pid, errors, telemetry, averages)
              pid
            other ->
              Logger.warn("RTA Loader: Unable to start mci #{inspect(mci)}, got #{inspect(other)}")
              nil
          end
        pid ->
          Backend.RealTimeAnalytics.MCIProcess.reset_with(pid, errors, telemetry, averages)
          pid
      end

    {:ok, pid}
  end

  @impl true
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    Logger.info("RTA Loader - Starting state handoff")
    {:reply, {:resume, state}, state}
  end

  @impl true
  def terminate(:shutdown, state) do
    Logger.info("RTA Loader Beginning loader process termination. Reason: :shutdown. Starting handoff.")
    Swarm.Tracker.handoff(__MODULE__, state)
  end
  @impl true
  def terminate(reason, _state) do
    Logger.info("RTA Loader: Beginning loader process termination. Reason: #{inspect reason}")
  end
end
