defmodule Backend.RealTimeAnalytics.Analysis do
  @moduledoc """
  This process is responsible for running Analysis and keeping track of analyzer configs
  """

  use GenServer
  use TypedStruct
  require Logger

  alias Backend.Projections.Dbpa.{AnalyzerConfig, Monitor, MonitorCheck, MonitorEvent, StatusPage}
  alias Backend.Projections.Dbpa.Snapshot
  alias Backend.RealTimeAnalytics.{Snapshotting, Alerting, MCIProcess, SwarmSupervisor}

  # We limit change notifications to this rate.
  @broadcast_interval_ms 1_000

  typedstruct module: State, enforce: true do
    field :account_id, String.t()
    field :monitor, %Monitor{}
    field :analyzer_config, %AnalyzerConfig{}
    field :current_snapshot, Snapshot.Snapshot.t()
    field :steps, [binary()]
    field :outstanding_monitor_events, Backend.RealTimeAnalytics.MonitorEvents.t()
    field :initialized, binary()
    field :last_broadcast, integer(), default: nil
    field :broadcast_delay_timer, reference, default: nil
    field :status_page, StatusPage.t(), default: nil
    field :status_page_subscriptions, [StatusPage.StatusPageSubscription.t()], default: []
  end

  def child_spec(args) do
    child_name = args[:child_name]

    %{
      id: child_name,
      restart: :transient,
      shutdown: 60_000,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  @spec start_analysis(binary(), binary()) :: {:already_running, any} | {:error, any} | {:ok, pid}
  def start_analysis(account_id, monitor_logical_name) do
    case lookup_child(account_id, monitor_logical_name) do
      nil ->
        case Backend.RealTimeAnalytics.SwarmSupervisor.start_analysis_child(
               account_id: account_id,
               monitor_logical_name: monitor_logical_name
             ) do
          {:ok, pid} ->
            {:ok, pid}
          {:error, {:already_started, pid}} ->
            {:already_running, pid}
          rest ->
            Logger.error("RTA Analysis: Error starting analysis child #{inspect(rest)}")
            rest
        end

      pid ->
        Logger.debug(
          "RTA Analysis: Found existing analysis process for Account ID: #{account_id} Monitor: #{monitor_logical_name}. PID is #{inspect(pid)}"
        )

        {:already_running, pid}
    end
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    account_id = Keyword.fetch!(args, :account_id)
    monitor_logical_name = Keyword.fetch!(args, :monitor_logical_name)

    Logger.debug(
      "RTA Analysis: Starting Analysis process for Account ID: #{account_id} Monitor: #{monitor_logical_name}"
    )

    GenServer.start_link(__MODULE__, args, name: name)
  end

  # Loader is the only thing that can call this. Analysis state handoff will happen before this
  # so that this process can still serve up the snapshot while the loader runs
  # When loader calls this, we are guaranteed that all MCI's that this analysis process should need
  # are loaded and have been reset with current data
  @spec initialize(pid, %Monitor{}, %AnalyzerConfig{}, [%MonitorEvent{}]) :: :ok
  def initialize(pid, monitor, analyzer_config, outstanding_events) do
    GenServer.cast(pid, {:initialize, monitor, analyzer_config, outstanding_events})
  end

  # Public API

  def stop(pid) do
    GenServer.stop(pid)
  end

  @spec update_config(any, any, %AnalyzerConfig{}) :: any()
  def update_config(account_id, monitor_logical_name, updated_config) do
    case lookup_child(account_id, monitor_logical_name) do
      nil ->
        Logger.info(
          "RTA Analysis: Attempted to update config for unknown child. Account ID: #{account_id} Monitor: #{monitor_logical_name} PID: #{inspect(self())}"
        )

        :ignore

      pid ->
        GenServer.cast(pid, {:config_updated, updated_config})
    end
  end

  def remove_config(account_id, monitor_logical_name) do
    case lookup_child(account_id, monitor_logical_name) do
      nil ->
        Logger.info(
          "RTA Analysis: Attempted to remove config for unknown child. Account ID: #{account_id} Monitor: #{monitor_logical_name} PID: #{inspect(self())}"
        )

        :ignore

      pid ->
        GenServer.cast(pid, :config_removed)
    end
  end

  def add_check(account_id, monitor_logical_name, name, logical_name) do
    get_affected_analysis_processes_for_change(account_id, monitor_logical_name)
    |> Enum.each(fn child ->
      GenServer.cast(child, {:check_added, %{name: name, logical_name: logical_name}})
    end)
  end

  def remove_check(account_id, monitor_logical_name, logical_name) do
    get_affected_analysis_processes_for_change(account_id, monitor_logical_name)
    |> Enum.each(fn child ->
      GenServer.cast(child, {:check_removed, %{logical_name: logical_name}})
    end)
  end

  def update_check(account_id, monitor_logical_name, name, logical_name) do
    get_affected_analysis_processes_for_change(account_id, monitor_logical_name)
    |> Enum.each(fn child ->
      GenServer.cast(child, {:check_updated, %{name: name, logical_name: logical_name}})
    end)
  end

  @spec set_steps(binary(), binary(), [binary()]) :: :ok
  def set_steps(account_id, monitor_logical_name, steps) do
    get_affected_analysis_processes_for_change(account_id, monitor_logical_name)
    |> Enum.each(fn child ->
      GenServer.cast(child, {:steps_set, %{steps: steps, from_account_id: account_id}})
    end)
  end

  def get_monitor(account_id, monitor_logical_name) do
    case lookup_child(account_id, monitor_logical_name) do
      nil ->
        Logger.info(
          "RTA Analysis: Attempted to retrieve monitor for unknown child. Account ID: #{account_id} Monitor: #{monitor_logical_name} PID: #{inspect(self())}"
        )

        :ignore

      pid ->
        GenServer.call(pid, :get_monitor)
    end
  end

  def get_snapshot(account_id, monitor_logical_name) do
    try do
      if child = lookup_child(account_id, monitor_logical_name) do
        snapshot = GenServer.call(child, :get_snapshot, 1000)
        {:ok, snapshot}
      else
        {:error, :not_found}
      end
    catch
      :exit, value ->
        Logger.warn(
          """
          RTA Analysis: Unable to retrieve snapshot. For account id #{account_id} for monitor #{monitor_logical_name}.
          Error value: #{inspect value}
          """
        )

        {:error, :call_failure}
    end
  end

  @doc """
  Utility function to build the key for our via tuple value.
  """
  def child_name(account_id, monitor_logical_name) do
    {__MODULE__, account_id, monitor_logical_name}
  end

  # Local utility lookup
  def lookup_child(account_id, monitor_logical_name) do
    child_name = Backend.RealTimeAnalytics.Analysis.child_name(account_id, monitor_logical_name)

    case Swarm.whereis_name(child_name) do
      :undefined -> nil
      pid -> pid
    end
  end

  # Server side

  @impl true
  def init(args) do
    account_id = Keyword.fetch!(args, :account_id)
    monitor_logical_name = Keyword.fetch!(args, :monitor_logical_name)

    Logger.debug(
      "RTA Analysis: Initializing Analysis process for Account ID: #{account_id} Monitor: #{monitor_logical_name} PID: #{inspect(self())}"
    )

    state = %State{
      account_id: account_id,
      # We're going to put a monitor here just with logical name until :initialize can set the full proper one
      monitor: %Monitor{logical_name: monitor_logical_name},
      analyzer_config: nil,
      current_snapshot: nil,
      steps: [],
      outstanding_monitor_events: [],
      initialized: false,
      last_broadcast: :erlang.monotonic_time(:millisecond)
    }

    Process.flag(:trap_exit, true)

    Process.send_after(self(), :verify_initialized, 45_000)

    {:ok, state, {:continue, []}}
  end

  @impl true
  def handle_continue(_args, state) do
    Logger.debug(
      "RTA Analysis: Registering analysis process #{state.account_id}|#{state.monitor.logical_name}"
    )

    SwarmSupervisor.register_analysis_process(state.monitor.logical_name, self())
    {:noreply, state}
  end

  @impl true
  def terminate(:shutdown, state) do
    Logger.info(
      "RTA: Analysis: Beginning analysis process termination for #{state.account_id}|#{state.monitor.logical_name}. :shutdown"
    )

    Swarm.Tracker.handoff(child_name(state.account_id, state.monitor.logical_name), state)
  end

  def terminate(reason, state) do
    Logger.info(
      "RTA: Analysis: Other analysis process termination for #{state.account_id}|#{state.monitor.logical_name}. #{inspect(reason)}"
    )
  end

  # Trigger analysis updates on any published rta_monitor_change we are subscribed to
  @impl true
  def handle_call(:get_snapshot, _from, state) do
    {:reply, state.current_snapshot, state}
  end

  # Swarm will not call this when a node is terminating only when new nodes start up and swarm wants to redistribute the processes (which we don't use)
  # If we want to send different state when terminating we have to do that in our Swarm.Tracker.handoff(state.mci, state) call
  # end_handoff always gets called and can be used to reset state vars in either scenario
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    Logger.debug("RTA Analysis: Starting state handoff PID: #{inspect(self())}")
    {:reply, {:resume, state}, state}
  end

  def handle_call(:get_monitor, _from, state) do
    {:reply, state.monitor, state}
  end

  @impl true
  def handle_cast({:initialize, monitor, analyzer_config, outstanding_events}, state) do
    # Domain.Account.Events.MonitorAdded will cause this account to be subscribed to all status page components. The StatusPageCache which is used
    # to load the subscriptions during assign_status_page_info() may not be aware of the new subscriptions yet if the monitor was just added to the account
    # especially if the analysis process gets spawned on another node as pubsub has to make it over there to update the cache.
    # The SubscriptionAdded events may have already fired so subscribe_to_status_page_component_changes won't catch them either (race condition here).
    # This let's everything converge w.r.t status page subscriptions and then builds the full snapshot a second time.
    if Timex.diff(NaiveDateTime.utc_now(), monitor.inserted_at, :milliseconds) < 1_000 do
      Logger.debug(
        "RTA Analysis: Monitor was just added to the account, we're going to delay status page initialization slightly to allow for event handlers to fire. PID: #{inspect(self())}"
      )
      Process.send_after(self(), :status_page_initialize, 2_000)
    end

    Logger.debug(
      "RTA Analysis: initializing and starting to listen to MCI events for Account ID: #{state.account_id} Monitor: #{monitor.logical_name} PID: #{inspect(self())}"
    )

    new_state = %State{
      account_id: state.account_id,
      monitor: get_simple_monitor(monitor),
      analyzer_config: analyzer_config,
      current_snapshot: state.current_snapshot,
      steps: get_steps(monitor),
      outstanding_monitor_events: [],
      initialized: true
    }
    |> assign_status_page_info()
    |> load_outstanding_monitor_events(outstanding_events)

    new_state =
      case state.current_snapshot do
        nil ->
          Logger.debug(
            "RTA Analysis: current_snapshot does not exist, initializing_snapshot PID: #{inspect(self())}"
          )

          new_state
          |> initialize_snapshot()

        _snapshot ->
          Logger.debug(
            "RTA Analysis: current_snapshot already exists, not initializing_snapshot PID: #{inspect(self())}"
          )

          new_state
      end

    subscribe_to_mci_changes(new_state.account_id, new_state.monitor.logical_name)
    subscribe_to_status_page_component_changes(new_state.status_page)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:swarm, :end_handoff, newState}, state) do
    Logger.debug(
      "RTA Analysis: Received state from swarm, setting it. #{state.monitor.logical_name} #{state.account_id} PID: #{inspect(self())}"
    )

    {:noreply,
     %State{
       newState
       | initialized: state.initialized,
         last_broadcast: nil,
         broadcast_delay_timer: nil
     }}
  end

  def handle_cast({:swarm, :resolve_conflict, _newState}, state) do
    {:noreply, state}
  end

  def handle_cast(:config_removed, state) do
    Logger.info(
      "RTA Analysis: Config removed. Stopping Analysis process for Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} PID: #{inspect(self())}"
    )

    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:config_updated, _updated_config}, %State{initialized: false} = state) do
    Logger.info(
      "RTA Analysis: Got config_updated but the analysis process is not yet initialized. Ignoring. PID: #{inspect(self())}"
    )

    {:noreply, state}
  end

  def handle_cast({:config_updated, updated_config}, state) do
    Logger.info(
      "RTA Analysis: Config updated for Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} PID: #{inspect(self())}"
    )

    state = %State{state | analyzer_config: updated_config}
    state = initialize_snapshot(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:check_added, %{name: _name, logical_name: _logical_name}},
        %State{initialized: false} = state
      ) do
    Logger.info(
      "RTA Analysis: Got check_added but the analysis process is not yet initialized. Ignoring. PID: #{inspect(self())}"
    )

    {:noreply, state}
  end

  def handle_cast({:check_added, %{name: name, logical_name: logical_name}}, state) do
    Logger.info(
      "RTA Analysis: Check added Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} Check: #{logical_name} PID: #{inspect(self())}"
    )

    updated_checks = [
      %MonitorCheck{name: name, logical_name: logical_name} | state.monitor.checks
    ]

    {:noreply, %State{state | monitor: %{state.monitor | checks: updated_checks}}}
  end

  @impl true
  def handle_cast(
        {:check_removed, %{logical_name: _logical_name}},
        %State{initialized: false} = state
      ) do
    Logger.info(
      "RTA Analysis: Got check_removed but the analysis process is not yet initialized. Ignoring. PID: #{inspect(self())}"
    )

    {:noreply, state}
  end

  def handle_cast({:check_removed, %{logical_name: logical_name}}, state) do
    Logger.info(
      "RTA Analysis: Check removed Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} Check: #{logical_name} PID: #{inspect(self())}"
    )

    updated_checks =
      Enum.reject(state.monitor.checks, fn check -> check.logical_name == logical_name end)

    {:noreply, %State{state | monitor: %{state.monitor | checks: updated_checks}}}
  end

  @impl true
  def handle_cast(
        {:check_updated, %{name: _name, logical_name: _logical_name}},
        %State{initialized: false} = state
      ) do
    Logger.info(
      "RTA Analysis: Got check_updated but the analysis process is not yet initialized. Ignoring. PID: #{inspect(self())}"
    )

    {:noreply, state}
  end

  def handle_cast({:check_updated, %{name: name, logical_name: logical_name}}, state) do
    Logger.info(
      "RTA Analysis: Check updated Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} Check: #{logical_name} PID: #{inspect(self())}"
    )

    updated_checks =
      Enum.map(state.monitor.checks, fn check ->
        case check.logical_name do
          ^logical_name -> %MonitorCheck{check | name: name}
          _ -> check
        end
      end)

    {:noreply, %State{state | monitor: %{state.monitor | checks: updated_checks}}}
  end

  def handle_cast({:steps_set, %{steps: steps, from_account_id: _}}, state) do
    Logger.info(
      "RTA Analysis: Updating steps for Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} PID: #{inspect(self())}"
    )

    {:noreply, %State{state | steps: steps}}
  end

  @impl true
  def handle_info(%{mci: mci, pid: pid}, state) do
    state =
      case state.current_snapshot do
        nil -> initialize_snapshot(state)
        _ -> update_snapshot(state, mci, pid)
      end

    {:noreply, state}
  end

  def handle_info(:verify_initialized, %State{initialized: false} = state) do
    Logger.debug(
      "RTA Analysis: Analysis process was not initialized after 45 seconds. Requesting Loader initialization Account ID: #{state.account_id} Monitor: #{state.monitor.logical_name} PID: #{inspect(self())}"
    )

    Backend.RealTimeAnalytics.Loader.request_initialization()
    {:noreply, state}
  end

  def handle_info(:verify_initialized, state), do: {:noreply, state}

  def handle_info({:swarm, :die}, state) do
    {:stop, :normal, state}
  end

  def handle_info(:status_page_initialize, state) do
    {
      :noreply,
      state
      |> assign_status_page_info()
      |> initialize_snapshot()
    }
  end

  def handle_info(%{event: %Domain.StatusPage.Events.ComponentStatusChanged{} = event}, %State{} = state)
    when state.current_snapshot != nil do
    state = if Enum.any?(state.status_page_subscriptions, & &1.component_id == event.component_id) do
      Logger.debug("RTA Analysis: #{inspect([account_id: state.account_id, monitor: state.monitor.logical_name, pid: self(), received: event.__struct__])}")
      previous_snapshot = state.current_snapshot
      new_snapshot = Snapshotting.update_status_page_component_check_details(state.current_snapshot, event)
      # We dont want to call process_new_snapshot/2 here because we want to avoid generating monitor events
      %State{state | current_snapshot: new_snapshot}
      |> run_alerting(previous_snapshot, new_snapshot)
    else
      state
    end
    {:noreply, state}
  end
  def handle_info(%{event: %Domain.StatusPage.Events.ComponentStatusChanged{}}, state) do
    {:noreply, state}
  end

  def handle_info(%{event: %Domain.StatusPage.Events.SubscriptionRemoved{account_id: account_id} = event}, %State{} = state)
    when account_id == state.account_id and state.current_snapshot != nil do
    Logger.debug("RTA Analysis: #{inspect([account_id: state.account_id, monitor: state.monitor.logical_name, pid: self(), received: event.__struct__])}")
    state = case Enum.split_with(state.status_page_subscriptions, & &1.id == event.subscription_id) do
      {[to_remove], subscriptions} ->
        snapshot = Snapshotting.remove_status_page_component_check_detail(state.current_snapshot, to_remove.component_id)
        %{state | current_snapshot: snapshot, status_page_subscriptions: subscriptions}
      _ -> state
    end
    {:noreply, state}
  end
  def handle_info(%{event: %Domain.StatusPage.Events.SubscriptionRemoved{}}, state) do
    {:noreply, state}
  end

  def handle_info(%{event: %Domain.StatusPage.Events.SubscriptionAdded{account_id: account_id} = event}, state)
    when account_id == state.account_id and state.current_snapshot != nil do
    Logger.debug("RTA Analysis: #{inspect([account_id: state.account_id, monitor: state.monitor.logical_name, pid: self(), received: event.__struct__])}")

    change = Backend.RealTimeAnalytics.StatusPageCache.component_change!(event.component_id)
    state = %{
      state
      | current_snapshot:
          Snapshotting.add_status_page_component_check_details(
            state.current_snapshot,
            event.component_id,
            change
          ),
        status_page_subscriptions: [
          %StatusPage.StatusPageSubscription{
            id: event.subscription_id,
            component_id: event.component_id,
            status_page_id: state.status_page.id
          }
          | state.status_page_subscriptions
        ]
    }
    {:noreply, state}
  end
  def handle_info(%{event: %Domain.StatusPage.Events.SubscriptionAdded{}}, state) do
    {:noreply, state}
  end
  def handle_info(%{event: e}, state) do
    Logger.debug("Unhandled pubsub event. #{inspect e}")
    {:noreply, state}
  end

  def handle_info({:broadcast_change, reason}, state) do
    now = :erlang.monotonic_time(:millisecond)

    not_before =
      if is_nil(state.last_broadcast) do
        # Make sure that we will broadcast the first time around.
        :erlang.monotonic_time(:millisecond) - @broadcast_interval_ms
      else
        state.last_broadcast + @broadcast_interval_ms
      end

    state =
      if now >= not_before do
        Logger.debug(
          "RTA Analysis: broadcast change for #{state.account_id}/#{state.monitor.logical_name}. PID: #{inspect(self())}, reason: #{reason}"
        )

        Backend.PubSub.broadcast_snapshot_state_changed!(
          state.account_id,
          state.monitor.logical_name,
          state.current_snapshot.state
        )

        %State{state | last_broadcast: now}
      else
        Logger.info(
          "RTA Analysis: limiting change broadcast rate for #{state.account_id}/#{state.monitor.logical_name}. PID: #{inspect(self())}, reason: #{reason}"
        )

        if not is_nil(state.broadcast_delay_timer),
          do: Process.cancel_timer(state.broadcast_delay_timer)

        timer = Process.send_after(self(), {:broadcast_change, "delay timer"}, not_before - now)
        %State{state | broadcast_delay_timer: timer}
      end

    {:noreply, state}
  end

  # Helpers

  defp subscribe_to_mci_changes(account_id, monitor_logical_name) do
    Backend.PubSub.subscribe_rta_monitor_changes(account_id, monitor_logical_name)
  end

  defp subscribe_to_status_page_component_changes(status_page)
    when status_page != nil do
    cmds = [
      # All the keys are enforced so a list of nils here
      %Domain.StatusPage.Events.ComponentStatusChanged{
        id: status_page.id,
        change_id: nil,
        component: nil,
        status: nil,
        state: nil,
        instance: nil,
        changed_at: nil
      },
      %Domain.StatusPage.Events.SubscriptionAdded{id: status_page.id},
      %Domain.StatusPage.Events.SubscriptionRemoved{id: status_page.id}
    ]

    Enum.each(cmds, fn topic ->
      Backend.PubSub.unsubscribe_to_topic_of(topic)
      Backend.PubSub.subscribe_to_topic_of(topic)
    end)
  end

  defp subscribe_to_status_page_component_changes(_status_page), do: nil

  defp get_simple_monitor(monitor) do
    # Keep only what's required in memory
    %Monitor{
      name: monitor.name,
      logical_name: monitor.logical_name,
      checks:
        Enum.map(monitor.checks, fn check ->
          %MonitorCheck{name: check.name, logical_name: check.logical_name}
        end),
      inserted_at: monitor.inserted_at
    }
  end

  defp get_affected_analysis_processes_for_change(account_id, monitor_logical_name) do
    [lookup_child(account_id, monitor_logical_name)]
    |> Enum.reject(&(&1 == nil))
  end

  defp get_steps(nil), do: []

  defp get_steps(monitor) do
    case Ecto.assoc_loaded?(monitor.monitor_configs) do
      false ->
        []

      true ->
        Enum.map(monitor.monitor_configs, fn cfg ->
          case cfg.steps == nil do
            true ->
              []

            false ->
              Enum.map(cfg.steps, fn step -> Map.get(step, "check_logical_name") end)
          end
        end)
        |> List.flatten()
    end
  end

  defp initialize_snapshot(state) do
    try do
      Logger.debug(
        "RTA Analysis: Initializing Snapshot for account id #{state.account_id} for monitor #{state.monitor.logical_name} PID: #{inspect(self())}"
      )

      mci_pids =
        SwarmSupervisor.get_all_mci_processes_for_account_and_monitor(
          state.account_id,
          state.monitor.logical_name
        )

      Logger.debug(
        "RTA Analysis: MCIS to use for #{state.account_id} for monitor #{state.monitor.logical_name} PID: #{inspect(self())} MCI: #{inspect(mci_pids)}"
      )

      telemetry_by_mci =
        Enum.map(mci_pids, fn pid ->
          {
            MCIProcess.mci(pid),
            MCIProcess.telemetry(pid),
            MCIProcess.average(pid),
            MCIProcess.errors(pid)
          }
        end)


      corr_id = case state.outstanding_monitor_events do
        [] -> nil
        _ -> List.first(state.outstanding_monitor_events) |>  elem(3)
      end
      if Enum.any?(telemetry_by_mci, &is_nil/1) do
        Logger.info(
          "RTA Analysis: Couldn't retrieve some MCI data, so could not initialize account id: #{state.account_id} for monitor #{state.monitor.logical_name} PID: #{inspect(self())}"
        )

        state
      else
        {time, snapshot} =
          :timer.tc(
            fn ->
              component_ids = Enum.map(state.status_page_subscriptions, & &1.component_id)
              Snapshotting.build_full_snapshot(
                telemetry_by_mci,
                Backend.RealTimeAnalytics.StatusPageCache.component_changes(component_ids),
                AnalyzerConfig.transform_check_configs(state.analyzer_config),
                state.monitor,
                state.steps,
                corr_id
              )
            end,
            []
          )

        Logger.debug(
          "RTA Analysis: build_full_snapshot took #{time}µs for account id #{state.account_id} for monitor #{state.monitor.logical_name} PID: #{inspect(self())}"
        )

        process_new_snapshot(state, snapshot)
      end
    catch
      :exit, value ->
        Logger.warn(
          """

          RTA Analysis: We caught a Genserver exit. Possible the node that contains the MCI is shutting down and Swarm hasn't fully updated its registry yet.
          Could not initialize.
          Error value: #{inspect value}
          """
        )
        state
    end
  end

  defp update_snapshot(state, mci, pid) do
    Logger.debug(
      "RTA Analysis: Running update_snapshot for account id #{state.account_id} for monitor #{state.monitor.logical_name} PID: #{inspect(self())}"
    )

    telemetry = MCIProcess.telemetry(pid)
    average = MCIProcess.average(pid)
    errors = MCIProcess.errors(pid)

    snapshot =
      Snapshotting.update_snapshot(
        state.current_snapshot,
        mci,
        telemetry,
        average,
        errors,
        AnalyzerConfig.transform_check_configs(state.analyzer_config),
        state.monitor,
        state.steps
      )

    Logger.debug(
      "RTA Analysis: Updated snapshot for account id #{state.account_id} for monitor #{state.monitor.logical_name} PID: #{inspect(self())}"
    )

    process_new_snapshot(state, snapshot)
  end

  defp process_new_snapshot(state, snapshot) do
    state =
      state
      |> run_alerting(state.current_snapshot, snapshot)
      |> process_monitor_events(state.current_snapshot, snapshot)

    Backend.MonitorSnapshotTelemetry.maybe_execute_metric(
      state.account_id,
      state.monitor.logical_name,
      state.current_snapshot,
      snapshot
    )

    %State{state | current_snapshot: snapshot}
  end

  defp run_alerting(state, previous_snapshot, current_snapshot) do
    {:ok, alerts_sent} =
      Alerting.maybe_create_and_dispatch_alerts(
        previous_snapshot,
        current_snapshot,
        state.monitor,
        state.account_id,
        state.outstanding_monitor_events
      )

    if (is_nil(previous_snapshot) and not is_nil(current_snapshot)) or alerts_sent > 0 do
      # Snapshot state or Check details state was changed if an alert is sent.
      send(self(), {:broadcast_change, "state changed"})
    end

    state
  end

  defp process_monitor_events(state, previous_snapshot, current_snapshot) do
    previous_check_details =
      if previous_snapshot do
        previous_snapshot.check_details
      else
        []
      end

    monitor_events =
      if current_snapshot != nil do
        {monitor_events, commands} =
          Backend.RealTimeAnalytics.MonitorEvents.process_events(
            previous_check_details,
            current_snapshot.check_details,
            state.outstanding_monitor_events,
            account_id: state.account_id,
            monitor_id: current_snapshot.monitor_id,
            correlation_id: current_snapshot.correlation_id,
            new_snapshot_state: current_snapshot.state
          )

        Enum.each(commands, &Backend.App.dispatch/1)
        monitor_events
      else
        []
      end

    %State{state | outstanding_monitor_events: monitor_events}
  end

  defp load_outstanding_monitor_events(state, outstanding_events) do
    events =
      for monitor_event <- outstanding_events do
        {monitor_event.id, monitor_event.check_logical_name, monitor_event.instance_name, monitor_event.correlation_id, monitor_event.state}
      end

    %State{state | outstanding_monitor_events: events}
  end

  defp assign_status_page_info(state) do
    if status_page = Backend.RealTimeAnalytics.StatusPageCache.status_page(state.monitor.logical_name) do
      %{state |
        status_page: status_page,
        status_page_subscriptions: Backend.RealTimeAnalytics.StatusPageCache.subscriptions(state.account_id, status_page.id)
      }
    else
      state
    end
  end
end
