defmodule Backend.App do

  alias Domain.Monitor.Commands, as: MonitorCmds

  require Logger

  snapshot_every = if Application.get_application(Mix) != nil && Mix.env in [:dev, :test],
    do: 2,
    else: 100

  use Commanded.Application,
    otp_app: :backend,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: Backend.EventStore
    ],
    pubsub: [
      phoenix_pubsub: [
        adapter: Phoenix.PubSub.PG2,
        pool_size: 1
      ]
    ],
    registry: :global,
    snapshotting: %{
      Domain.Monitor => [
        snapshot_every: snapshot_every,
        snapshot_version: 2
      ],
      Domain.Account => [
        snapshot_every: snapshot_every,
        snapshot_version: 4
      ],
      Domain.StatusPage => [
        snapshot_every: snapshot_every,
        snapshot_version: 4
      ],
      Domain.IssueTracker => [
        snapshot_every: snapshot_every,
        snapshot_version: 2
      ]
    }

  router Backend.Router

  def init (config) do
    {tenant, config} = case Keyword.pop(config, :tenant) do
      {nil, config} -> {:public, config}
      {tenant, config} -> {tenant, config}
    end

    # Set dynamic event store name
    config = case Keyword.fetch(config, :name) do
      :error -> config
      {:ok, name} -> put_in(config, [:event_store, :name], Module.concat([name, EventStore]))
    end

    # Set event store prefix (Postgres schema)
    config = put_in(config, [:event_store, :prefix], Atom.to_string(tenant))

    {:ok, config}
  end

  defmodule DelayingSupervisor do
      use Supervisor
      require Logger

      def child_spec(opts) do
          Backend.App.child_spec(opts)
          |> Map.put(:start, {__MODULE__, :start_link, [opts]})
      end
      def start_link(opts) do
          Logger.info("Delaying App start by 50ms to release name registration")
          Process.sleep(50)
          Backend.App.start_link(opts)

          migration_opts = opts
            |> Keyword.put(:name, :migration)
            |> Keyword.put(:tenant, :migration)
          Backend.App.start_link(migration_opts)
      end
      defdelegate init(opts), to: Commanded.Application.Supervisor
  end

  def dispatch_with_actor(actor, command, opts \\ []) do
    opts = opts
    |> Keyword.put_new(:metadata, %{})
    |> put_in([:metadata, :actor], actor)
    dispatch_with_retries(command, opts, 3)
  end

  defp dispatch_with_retries(%MonitorCmds.AddTelemetry{} = command, opts, _retries) do
    # only try AddTelemetry command once
    try do
      dispatch(command, opts)
    rescue
      error ->
        Logger.info("Got error on dispatch; error=#{inspect error}")
    catch
      :exit, reason ->
        Logger.error("GenServer exit exception #{inspect reason} on dispatch; command=#{inspect command} with opts #{inspect opts}")
      val ->
        Logger.error("GenServer exception catch #{inspect val} on dispatch; command=#{inspect command} with opts #{inspect opts}")

    end
  end

  defp dispatch_with_retries(command, opts, 0) do
    Logger.error("No retries left on command #{inspect command} with opts #{inspect opts}")
    {:error, :no_retries_left}
  end

  defp dispatch_with_retries(command, opts, retries) do
    try do
      dispatch(command, opts)
    rescue
      error ->
        Logger.info("Got error on dispatch, retrying; error=#{inspect error}")
        Process.sleep(10)
        dispatch_with_retries(command, opts, retries - 1)
    catch
      :exit, reason ->
        Logger.error("GenServer exit exception #{inspect reason} on dispatch; command=#{inspect command} with opts #{inspect opts}")
      val ->
        Logger.error("GenServer exception catch #{inspect val} on dispatch; command=#{inspect command} with opts #{inspect opts}")
    end
  end
end
