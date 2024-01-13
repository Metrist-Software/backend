defmodule Backend.RealTimeAnalytics.LoaderHandoff do
  @moduledoc """
  This module will always be the last one terminated by the SwarmSupervisor.

  If it responsible for triggering loader re-initialization after a node shuts down
  """

  use GenServer, shutdown: 30_000
  use TypedStruct

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("RTA Loader Handoff: Terminate called")
    Logger.info("RTA Loader Handoff: Starting Loader Initialization")

    case Backend.Utils.do_with_retries(
      fn n ->
        Logger.info("RTA Loader Handoff: Waiting for new loader pid #{n}/20")
        Swarm.whereis_name(Backend.RealTimeAnalytics.SwarmSupervisor.loader_name())
      end,
      success_check: fn pid_or_undefined ->
        case pid_or_undefined do
          :undefined -> false
          pid -> !(node(pid) == node(self()))
        end
      end,
      max_attempts: 20,
      sleep_time: 500
    ) do
      {:ok, pid} ->
        Logger.info("RTA Loader Handoff: New loader pid is #{inspect pid}")
        Backend.RealTimeAnalytics.Loader.initialize_loader(pid)
      {:error, _ } ->
        Logger.warn("RTA Loader Handoff: Timeout waiting for new loader PID. Not initializing it.")
    end
  end
end

defmodule Backend.RealTimeAnalytics.SwarmSupervisor do
  alias Backend.RealTimeAnalytics.MCIProcess
  require Logger

  # Deliberately using Supervisor here instead of DynamicSupervisor as we need the termination order to be
  # deterministic. With DynamicSupervisor all children are sent the exit signal asynchronously but Supervisor
  # sends the exit signal in reverse order guaranteeing that Loader is re-initialized after all the other state handoffs
  # to other nodes
  # Termination order:
  #   All dynamic processes
  #   Loader Handoff
  use Supervisor, shutdown: 60_000

  def start_link(_args) do
    {:ok, pid} = Supervisor.start_link(__MODULE__, [], name: __MODULE__)
    Task.async(fn ->
      # Load the Status Page Cache on all nodes
      Backend.RealTimeAnalytics.StatusPageCache.initialize()

      startup_attempts = Backend.config([Backend.RealTimeAnalytics, :rta_startup_attempts])

      Backend.Utils.do_with_retries(
        fn n ->
          Logger.info("RTA startup attempt #{n}/#{startup_attempts}")
          case Node.list() do
            [] -> []
            other ->
              # Found another node. Let's give swarm a few seconds to converge
              # just in case libcluster annouced the other node right at the 4.99999
              # second mark. This will not impact state handoff, that happens
              # immediately between the running nodes on termination
              Process.sleep(:timer.seconds(2))
              other
          end
        end,
        success_check: & !Enum.empty?(&1),
        max_attempts: startup_attempts,
        sleep_time: 5_000
      )

      Logger.info("Continuing with RTA startup. Connected nodes are #{inspect(Node.list())}")

      case Backend.config([Backend.RealTimeAnalytics, :enabled]) do
        true -> do_loader_startup()
        _ -> Logger.warn("NOT STARTING RTA LOADER AS RTA IS NOT ENABLED!!! THIS SHOULD ONLY BE THE CASE ON DEV IN SPECIFIC CIRCUMSTANCES SUCH AS RESEENDING")
      end
    end)
    {:ok, pid}
  end

  @impl true
  def init(_) do
    Supervisor.init([Backend.RealTimeAnalytics.LoaderHandoff, Backend.RealTimeAnalytics.StatusPageCache], strategy: :one_for_one)
  end

  def do_loader_startup() do
    case Swarm.whereis_name(loader_name()) do
      :undefined ->
        Logger.info("RTA startup: Loader is undefined, starting it.")
        {:ok, pid} =
          Swarm.register_name(Backend.RealTimeAnalytics.Loader, __MODULE__, :start_loader, [[name: Backend.RealTimeAnalytics.Loader]], :infinity)
          Backend.RealTimeAnalytics.Loader.initialize_loader(pid)
        pid
      pid ->
        pid
    end
  end

  def start_loader(args) do
    case Supervisor.start_child(
      __MODULE__,
      {Backend.RealTimeAnalytics.Loader, args}
    ) do
      {:error, :already_present} ->
        Supervisor.restart_child(__MODULE__, Backend.RealTimeAnalytics.Loader)
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc """
  Launch a new worker child, specified uniquely with the `mci` tuple containing `{account, monitor, check, instance}`.
  """
  def start_child(mci, opts \\ []) do
    options = [
      name: __MODULE__,
      errors: [],
      telemetry: [],
      averages: []
    ]
    |> Keyword.merge(opts)

    args = Keyword.merge(options, [
      mci: mci,
      name: nil,
    ])

    case Swarm.register_name(mci, __MODULE__, :do_start_child, [args]) do
      {:ok, pid} ->
        register_mci_process(mci, pid)
        {:ok, pid}
      other -> other
    end
  end

  def do_start_child(args) do
    case Supervisor.start_child(
      __MODULE__,
      {Backend.RealTimeAnalytics.MCIProcess, args}
    ) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  def stop_child(mci) do
    case Swarm.whereis_name(mci) do
      :undefined ->
        {:error, :not_running}
      pid ->
        unregister_mci_process(mci, pid)
        Swarm.unregister_name(mci)
        MCIProcess.stop(pid)
        Supervisor.delete_child(__MODULE__, mci)
    end
  end

  def register_mci_process({account_id, monitor_logical_name, _, _}, pid) do
    Swarm.join("mcis-#{account_id}-#{monitor_logical_name}", pid)
  end

  def unregister_mci_process({account_id, monitor_logical_name, _, _}, pid) do
    Swarm.leave("mcis-#{account_id}-#{monitor_logical_name}", pid)
  end

  def start_analysis_child(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    monitor_logical_name = Keyword.fetch!(opts, :monitor_logical_name)
    child_name = Backend.RealTimeAnalytics.Analysis.child_name(account_id, monitor_logical_name)

    case Swarm.register_name(child_name, __MODULE__, :do_start_analysis_child, [Keyword.merge(opts, [child_name: child_name, name: nil])]) do
      {:ok, pid} ->
        register_analysis_process(monitor_logical_name, pid)
        {:ok, pid}
      other -> other
    end
  end

  def stop_analysis_child(opts) do
    account_id = Keyword.fetch!(opts, :account_id)
    monitor_logical_name = Keyword.fetch!(opts, :monitor_logical_name)
    child_name = Backend.RealTimeAnalytics.Analysis.child_name(account_id, monitor_logical_name)

    case Backend.RealTimeAnalytics.Analysis.lookup_child(account_id, monitor_logical_name) do
      nil ->
        {:error, :not_running}
      pid ->
        unregister_analysis_process(monitor_logical_name, pid)
        Swarm.unregister_name(child_name)
        Backend.RealTimeAnalytics.Analysis.stop(pid)
        Supervisor.delete_child(__MODULE__, child_name)
    end
  end

  def register_analysis_process(monitor_logical_name, pid) do
    Swarm.join("analysis-#{monitor_logical_name}", pid)
  end

  def unregister_analysis_process(monitor_logical_name, pid) do
    Swarm.leave("analysis-#{monitor_logical_name}", pid)
  end

  @doc """
  Starts the analysis worker child
  """
  def do_start_analysis_child(args, retry_from_already_present \\ false) do
    case Supervisor.start_child(
      __MODULE__,
      {Backend.RealTimeAnalytics.Analysis, args}
    ) do
      {:error, :already_present} ->
        Logger.info(
          """
          We have an analysis child_spec with id of #{inspect args[:child_name]} already but it isn't running. \
          Delete the childspec and try again.
          """
        )
        :ok = Supervisor.delete_child(__MODULE__, args[:child_name])
        unless retry_from_already_present do
          do_start_analysis_child(args, true)
        else
          Logger.warn(
            """
            We have an analysis child_spec with id of #{inspect args[:child_name]} already but it isn't running. \
            We already tried to delete and restart but that didn't work... ignoring...
            """
          )
        end
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @spec dispatch_telemetry(Domain.Monitor.Events.TelemetryAdded.t()) :: :ok
  def dispatch_telemetry(e) do
    mci = {e.account_id, e.monitor_logical_name, e.check_logical_name, e.instance_name}
    dispatch(mci, {:add_telemetry, e.created_at, e.value})
  end

  @spec dispatch_error(Domain.Monitor.Events.ErrorAdded.t()) :: :ok
  def dispatch_error(e) do
    mci = {e.account_id, e.monitor_logical_name, e.check_logical_name, e.instance_name}
    dispatch(mci, {:add_error, e.time, %{
      error_id: e.error_id,
      blocked_steps: e.blocked_steps
    }})
  end

  defp dispatch(mci, message) do
    case Swarm.whereis_name(mci) do
      :undefined ->
        case Swarm.whereis_name(loader_name()) do
          :undefined ->
            Logger.warn("RTA: Loader process not found. Dropping data from RTA")
          pid ->
            Logger.info("RTA: Spawning child because of error/telemetry data for unknown child #{inspect mci}: #{inspect message}")
            Backend.RealTimeAnalytics.Loader.init_mci(pid, mci, message)
        end
      pid ->
        GenServer.cast(pid, message)
    end
  end

  def get_all_mci_processes_for_account_and_monitor(account_id, monitor_logical_name) do
    Swarm.members("mcis-#{account_id}-#{monitor_logical_name}")
  end

  def get_all_analysis_processes_for_monitor(monitor_logical_name) do
    Swarm.members("analysis-#{monitor_logical_name}")
  end

  def loader_name(), do: Backend.RealTimeAnalytics.Loader
end
