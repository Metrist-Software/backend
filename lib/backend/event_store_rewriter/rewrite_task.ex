defmodule Backend.EventStoreRewriter.RewriteTask do
  use Task
  require Logger
  alias Backend.EventStoreRewriter.MigrationState

  @batch_size 1_000

  def start_link(opts \\ []) do
    migration = Keyword.fetch!(opts, :migration)
    Task.start_link(__MODULE__, :run, [migration])
  end

  def run(migration) do
    case :code.module_status(migration) do
      :loaded ->
        :global.trans({migration.name, self()}, fn ->
          run_in_lock(migration)
        end)

      _ ->
        Logger.error("Invalid migration module #{migration} specified!")
        {:error, :invalid_migration}
    end
  end

  defp run_in_lock(migration) do
    # Use the event_store as the name in order to pull from the source event store instead of the migration's
    state = MigrationState.read(migration.event_store(), migration.event_store())

    if state.migration_name == migration.name() do
      # Already completed and using this migration, nothing to do
      :ok
    else
      run_migration(migration)
    end
  end

  def run_migration(migration) do
    {:ok, conn, admin_conn} = Backend.EventStoreRewriter.Supervisor.start_event_store(migration)

    # TODO: persistent_term likely won't work for this since it doesn't work multi node
    # Will need another approach for the commanded middleware to properly read from
    :persistent_term.put(persistent_term_key(), :running)

    copy_events(migration, conn)

    migration
    |> start_snapshotting(conn)
    |> wait_for_snapshotting()

    # Once we've finished the first go through, we want to essentially re-run the whole process to
    # catch any events that we would have received while snapshotting, but this time not accept new
    # events so that we know there won't be any that aren't copied over
    # Depending on how long this takes, we may even want to repeat more than once until doing so
    # with the event lock in place
    copy_events(migration, conn, lock_event_store: true)

    migration
    |> start_snapshotting(conn)
    |> wait_for_snapshotting()

    # Waits for the subscription table to stop changing
    # then copies it over to the new schema
    copy_subscription_table(conn, migration)

    # Once we're confident that we've copied everything over, we can let the
    # migration do it's final bits of processing
    transfer_event_store(migration, admin_conn)

    # TODO: Need to stop all nodes
    :init.stop()

    {:noreply, %{}}
  end

  defp copy_events(migration, conn, opts \\ []) do
    lock_event_store = Keyword.get(opts, :lock_event_store, false)

    state = MigrationState.read(migration.event_store(), migration.name())
    starting_event_number = state.last_event_number + 1

    Logger.info(
      "Starting migration \"#{migration.name()}\" from event number #{starting_event_number}"
    )

    if lock_event_store do
      :persistent_term.put(persistent_term_key(), :finalizing)
    end

    starting_event_number
    |> migration.event_store().stream_all_forward(read_batch_size: @batch_size)
    |> Stream.chunk_every(@batch_size)
    |> transform_chunks(state.accumulator, migration)
    |> write_chunks(migration, conn)
    |> Stream.run()
  end

  # this method is public for testing
  def transform_chunks(stream, acc, handler) do
    # The accumulator for transformation is a map that the migration can use
    # as a scratch pad to keep state. We "thread" it through all chunks and
    # emit {events, acc} tuples per chunk to write to the database.

    # This code is tricky! We use the accumulator in two ways (we should write a cookbook,
    # startin with the recipe for "accumulator done two ways" ;-)). We thread it through
    # the Stream.transform call as normal to have updatable state for the migration,
    # but we need to snapshot it as well so we have to emit it with the events that result
    # from the migration's transformations.
    #
    # As Stream.transform expects that transformations return enumberables, we have to wrap
    # the `{events, acc}` tuple we want to pass to the next stage of processing in a list,
    # so `[{events, acc}]` it becomes.
    #
    # This is tricky, but with the above in mind it should not be too hard to follow the little
    # bit of code here; cleaner ways of writing this will probably all fail.
    #
    start_fun = fn -> acc end

    reducer = fn chunk, acc ->
      {events, acc} =
        Enum.reduce(chunk, {[], acc}, fn event, {events_acc, state_acc} ->
          {events, state_acc} = handler.handle_event(event, state_acc)
          {events_acc ++ events, state_acc}
        end)

      {[{events, acc}], acc}
    end

    last_fun = fn acc ->
      events = Enum.flat_map(acc, fn {k, v} -> handler.handle_last(k, v) end)
      {[{events, %{}}], acc}
    end

    after_fun = fn _acc -> nil end

    Stream.transform(stream, start_fun, reducer, last_fun, after_fun)
  end

  def get_status() do
    :persistent_term.get(persistent_term_key(), :inactive)
  end

  def persistent_term_key(), do: {__MODULE__, :status}

  defp write_chunks(stream, migration, conn) do
    # Per `transform_chunks`, above, we have a stream of {events, accumulator} chunks here.
    event_store = migration.event_store()
    name = migration.name()

    writer = fn {batch, acc} ->
      case batch do
        [] ->
          Logger.info("Skipping empty batch")

        batch ->
          Postgrex.transaction(conn, fn txn ->
            # get the event_number of the last event and stash that after the loop
            last =
              Enum.reduce(batch, 0, fn event, _last ->
                event_data = recorded_event_to_event_data(event)

                :ok =
                  event_store.append_to_stream(event.stream_uuid, :any_version, [event_data],
                    name: name,
                    conn: txn
                  )

                event.event_number
              end)

            Logger.info("Batch done, last is #{last}")

            if function_exported?(migration, :after_append_batch_to_stream, 3) do
              migration.after_append_batch_to_stream(batch, migration, txn)
            end

            :ok = MigrationState.write(migration.event_store(), migration.name(), last, acc, migration.name())
          end)
      end
    end

    Stream.map(stream, writer)
  end

  def transfer_event_store(migration, conn) do
    schema = migration.schema()

    # For some reason, just using `ALTER SCHEMA ...` doesn't seem to work with parameters
    # So we create a function to wrap the call that _can_ use parameters and call that instead
    query = """
    CREATE OR REPLACE FUNCTION public.rename_schema("from_name" character varying, "to_name" character varying)
      RETURNS void
      LANGUAGE plpgsql
    AS
    $$
    DECLARE
      from_name character varying;
      to_name character varying;
    BEGIN
      EXECUTE FORMAT('ALTER SCHEMA %I RENAME TO %I', $1, $2)

      RETURN;
    END;
    $$
    """

    Logger.info("Transfering event store schemas")

    Postgrex.transaction(conn, fn conn ->
      Postgrex.query!(conn, query, [])
      Postgrex.query!(conn, "DROP SCHEMA IF EXISTS public_bak CASCADE;", [])
      Postgrex.query!(conn, "SELECT public.rename_schema($1, $2)", ["public", "public_bak"])
      # The function _was_ on the public schema, but since we just moved it, we need to use the new namespace
      Postgrex.query!(conn, "SELECT public_bak.rename_schema($1, $2)", [schema, "public"])
    end)
  end

  defp recorded_event_to_event_data(re) do
    %EventStore.EventData{
      causation_id: re.causation_id,
      correlation_id: re.correlation_id,
      data: re.data,
      event_id: re.event_id,
      event_type: re.event_type,
      metadata: re.metadata
    }
  end

  def start_snapshotting(migration, conn) do
    Logger.info("Launching snapshotting tasks...")

    conn
    |> get_existing_snapshot_aggregate_ids()
    |> Enum.map(fn [id, module] ->
      module = String.to_existing_atom(module)
      {:ok, pid} = Backend.EventStoreRewriter.Supervisor.add_snapshotting_task(migration, module, id)
      pid
    end)
  end

  def wait_for_snapshotting(pids) do
    case Enum.filter(pids, &Process.alive?/1) do
      [] ->
        :ok
      remaining_pids ->
        Process.sleep(10_000)
        wait_for_snapshotting(remaining_pids)
    end
  end

  def create_snapshot_task(migration, module, id) do
    Task.start_link(__MODULE__, :create_snapshot, [migration, module, id])
  end

  def create_snapshot(migration, module, id) do
    event_store = migration.event_store()
    schema = migration.schema()
    name = migration.name()

    initial_snapshot = case event_store.read_snapshot(id, name: name, schema: schema) do
      {:ok, snapshot} ->
        snapshot
      _ ->
        %EventStore.Snapshots.SnapshotData{
          source_uuid: id,
          source_version: 0,
          source_type: "#{module}",
          data: struct(module),
          metadata: %{created_by: "migration", migration: migration.name()},
          created_at: DateTime.now!("Etc/UTC")
        }
    end

    starting_event_number = initial_snapshot.source_version + 1

    case event_store.stream_forward(id, starting_event_number, name: name, schema: schema) do
      {:error, :stream_not_found} ->
        Logger.info("Stream not found for #{id}. Copying directly with updated source_version.")

        {:ok, [last_event]} = event_store.read_all_streams_backward(-1, 1)
        {:ok, existing_snapshot} = event_store.read_snapshot(id)

        existing_snapshot
        |> Map.put(:source_version, last_event.event_number)
        |> event_store.record_snapshot(name: name, schema: schema)

      {:error, reason} ->
        Logger.error("Can not rebuild #{id} due to: #{reason}")

      stream ->
        Logger.info("Starting snapshot rebuild of #{id} from event # #{starting_event_number}")

        stream
        |> snapshot_transform(initial_snapshot, migration)
        |> Stream.take_every(@batch_size)
        |> Stream.each(fn snapshot ->
          event_store.record_snapshot(snapshot, name: name, schema: schema)
        end)
        |> Stream.run()
    end
  end

  def snapshot_transform(stream, initial_snapshot, migration) do
    event_store = migration.event_store()
    schema = migration.schema()
    name = migration.name()
    module = String.to_existing_atom(initial_snapshot.source_type)

    start_fun = fn -> initial_snapshot end

    reducer = fn event, agg ->
      snapshot = %EventStore.Snapshots.SnapshotData{
        agg
        | source_version: event.stream_version,
          data: module.apply(agg.data, event.data)
      }

      {
        [snapshot],
        snapshot
      }
    end

    last_fun = fn agg ->
      # Can skip writing the snapshot if there was't any updates
      if initial_snapshot.source_version != agg.source_version do
        Logger.info("Writing final snapshot for #{agg.source_uuid}")
        event_store.record_snapshot(agg, name: name, schema: schema)
      end

      {[], agg}
    end

    after_fun = fn _agg -> :ok end

    Stream.transform(stream, start_fun, reducer, last_fun, after_fun)
  end

  def get_existing_snapshot_aggregate_ids(conn) do
    {:ok, %Postgrex.Result{rows: rows}} =
      Postgrex.query(conn, "SELECT source_uuid, source_type FROM snapshots", [])

    rows
  end

  defp copy_subscription_table(conn, migration, opts \\ []) do
    max_retry = Keyword.get(opts, :max_retry, 20)
    max_equal_count = Keyword.get(opts, :max_equal_count, 5)
    sleep_duration_ms = Keyword.get(opts, :sleep_duration_ms, :timer.minutes(1))

    subscriptions = fn ->
      %Postgrex.Result{rows: rows} = Postgrex.query!(conn, "SELECT subscription_id, stream_uuid, last_seen FROM subscriptions", [])
      MapSet.new(rows, fn [subscription_id, stream_uuid, last_seen] -> {subscription_id, stream_uuid, last_seen} end)
    end

    initial_result = subscriptions.()
    equal_counter = 0

    Logger.info("Starting to poll for subscription changes")
    Enum.reduce_while(1..max_retry, {initial_result, equal_counter}, fn _attempt, {prev_result, equal_counter} = acc ->
      Logger.info("Sleeping for #{sleep_duration_ms}ms")
      Process.sleep(sleep_duration_ms)
      Logger.info("Sleep done")

      Logger.info("Querying for subscriptions")
      new_result = subscriptions.()
      Logger.info("Got #{MapSet.size(new_result)} subscriptions")

      equal_counter = if MapSet.equal?(prev_result, new_result) do
        Logger.info("Previous result is equal to new result. Counter is now #{equal_counter + 1}")
        equal_counter + 1
      else
        Logger.info("Previous result is NOT equal to previous resetting counter")
        0
      end

      if equal_counter > max_equal_count do
        Logger.info("Equal counter is gt max_equal_count. Halting")
        {:halt, acc}
      else
        Logger.info("Equal counter is NOT gt max_equal_count. Continuing")
        {:cont, {new_result, equal_counter}}
      end
    end)

    Logger.info("Copying subscriptions table to the new schema")
    Postgrex.query!(conn, """
      INSERT INTO "#{migration.schema()}".SUBSCRIPTIONS
      SELECT SUB.SUBSCRIPTION_ID,
        SUB.STREAM_UUID,
        SUB.SUBSCRIPTION_NAME,
        COALESCE(
          (SELECT STREAM_VERSION
              FROM "#{migration.schema()}".STREAMS
              WHERE STREAM_UUID = SUB.STREAM_UUID), 0) AS LAST_SEEN,
        SUB.CREATED_AT
      FROM
        (SELECT *
          FROM PUBLIC.SUBSCRIPTIONS) AS SUB
      ON CONFLICT ON CONSTRAINT subscriptions_pkey
      DO UPDATE SET LAST_SEEN = EXCLUDED.LAST_SEEN
      """, [])
    Logger.info("Copied subscriptions table successfuly")
  end
end
