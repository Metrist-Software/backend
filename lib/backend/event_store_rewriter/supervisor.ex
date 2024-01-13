defmodule Backend.EventStoreRewriter.Supervisor do
  @moduledoc """
  Dynamic supervisor to keep all the things under one roof.
  """
  use DynamicSupervisor
  require Logger

  def start_link(opts \\ []) do
    # Strictly speaking, we could have multiple migrations running concurrently and that should
    # therefore be part of the name. However, in practice, this won't happen so we keep addressing
    # the supervisor simple for now. If we try to start more, this will end with a loud bang directing
    # the future us to this very place in the code. Hi, future us! I hope y'all are doing well! ;-)
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

    {:ok, child} =
      DynamicSupervisor.start_child(__MODULE__, {Backend.EventStoreRewriter.RewriteTask, opts})

    Logger.info("Started rewrite supervisor as #{inspect(pid)} and worker as #{inspect(child)}")

    {:ok, pid}
  end

  def add_snapshotting_task(migration, module, id) do
    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, %{
      id: id,
      start: {Backend.EventStoreRewriter.RewriteTask, :create_snapshot_task, [migration, module, id]},
      restart: :transient
    })
  end

  def start_event_store(migration) do
    event_store = migration.event_store()
    existing_config = event_store.config()

    schema = migration.schema()
    name = migration.name()

    {:ok, _pid} =
      DynamicSupervisor.start_child(__MODULE__, {event_store, name: name, schema: schema})

    migration_config = Keyword.put(existing_config, :schema, schema)

    admin_details = Application.get_env(:backend, Backend.EventStoreRewriter)
    admin_username = Keyword.fetch!(admin_details, :admin_username)
    admin_password = Keyword.fetch!(admin_details, :admin_password)

    admin_config = migration_config
    |> Keyword.merge([username: admin_username, password: admin_password])

    config = EventStore.Config.default_postgrex_opts(migration_config)
    {:ok, conn} = DynamicSupervisor.start_child(__MODULE__, {Postgrex, config})

    config = EventStore.Config.default_postgrex_opts(admin_config)
    {:ok, admin_conn} = DynamicSupervisor.start_child(__MODULE__, {Postgrex, config})

    # TODO - Remove this. Obviously don't want to drop the new store at startup,
    # but it's handy for testing
    # Note: Obviously restart will not work until this is removed
    # EventStore.Tasks.Drop.exec(admin_config)

    case EventStore.Tasks.Create.exec(admin_config) do
      :ok ->
        EventStore.Tasks.Init.exec(admin_config)

        username = Keyword.fetch!(existing_config, :username)

        Postgrex.transaction(admin_conn, fn transaction ->
          Logger.info("Running tx")
          Postgrex.query!(transaction, "GRANT CREATE ON SCHEMA #{schema} TO #{username};", [])
          Postgrex.query!(transaction, "GRANT USAGE ON SCHEMA #{schema} TO #{username};", [])
          Postgrex.query!(transaction, "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} TO #{username};", [])
          Postgrex.query!(transaction, "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} TO #{username};", [])
        end)
      _ ->
        :ok
    end

    {:ok, conn, admin_conn}
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
