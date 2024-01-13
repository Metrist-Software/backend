defmodule Mix.Tasks.Metrist.SnapshotMigrate do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc "Generate new snapshots for aggregates"

  @opts [
    :env,
    {:aggregate, nil, :string, nil, "The specific aggregate to rebuild (Example: Elixir.Domain.Account, Elixir.Domain.StatusPage)"},
    {:restart_file, nil, :string, nil, "A file that contains aggregate ids that were already processed"}
  ]

  @moduledoc """
  Generate new snapshots for aggregates in preparation of an update to the
  shape of an aggregate

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Helpers.configure(options.env)

    Mix.Task.run("app.config")
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:commanded)
    Application.ensure_all_started(:commanded_eventstore_adapter)
    # Needed for Commanded Application Config lookups on Backend.App below
    {:ok, _} = Backend.App.start_link()

    Application.ensure_all_started(:logger)
    Logger.configure(level: Application.get_env(:logger, :level))

    # Needed for store_snapshot against a different tenant
    {:ok, _} = Backend.App.start_link(name: :migration, tenant: :migration)

    seen = if options.restart_file do
      options.restart_file
      |> File.read!()
      |> String.split()
    else
      []
    end
    if options.aggregate do
      Logger.info("Only rebuilding aggregates that match #{options.aggregate}")
    end

    aggregates = get_existing_snapshot_aggregate_ids()
      |> Enum.map(fn {aggregate, ids} ->
          if options.aggregate do
            case Atom.to_string(aggregate) == options.aggregate do
              true -> {aggregate, ids}
              _ -> nil
            end
          else
            {aggregate, ids}
          end
        end)
      |> Enum.reject(&(is_nil(&1)))

    snapshotting = Commanded.Application.Config.get(Backend.App, :snapshotting)

    fd = if options.restart_file, do: File.open!(options.restart_file, [:append])

    for {aggregate, ids} <- aggregates do
      Logger.info("=== Generating for aggregate: #{aggregate}")
      for id <- ids do
        if id in seen do
          Logger.info("=== Skipping #{id}, already seen")
        else
         state = build_aggregate(aggregate, id, snapshotting)
         store_snapshot(state, :migration)
         if fd, do: IO.puts(fd, id)
        end
      end
    end

    if fd, do: File.close(fd)

    Logger.info("Done")
  end

  defp store_snapshot(%{aggregate_module: aggregate_module, aggregate_uuid: id, snapshotting: snapshotting, aggregate_version: version, aggregate_state: state}, application) do
    Logger.info("Storing snapshot #{inspect aggregate_module}:#{inspect id}")
    snapshotting = Map.put(snapshotting, :application, application)
    Commanded.Snapshotting.take_snapshot(snapshotting, version, state)
  end

  defp build_aggregate(aggregate, id, snapshotting) do
    Logger.info("Building aggregate for #{inspect aggregate}:#{inspect id}")
    {:ok, pid} = Commanded.Aggregates.Aggregate.start_link(
      [application: Backend.App, snapshotting: snapshotting],
      [aggregate_module: aggregate, aggregate_uuid: id])

    state = :sys.get_state(pid, :infinity)

    GenServer.stop(pid)

    state

    # TODO: With upcoming Commanded version (1.3?), the above should be able to be replaced with the following
    # Commanded.Aggregates.AggregateStateBuilder.populate(%Commanded.Aggregates.Aggregate{
    #   application: Backend.App,
    #   aggregate_module: Domain.Account,
    #   aggregate_uuid: id,
    #   snapshotting: snapshotting
    # })
  end

  defp get_existing_snapshot_aggregate_ids() do
    {:ok, conn} = Postgrex.start_link(Application.get_env(:backend, Backend.EventStore))
    conn
    |> Backend.EventStoreRewriter.RewriteTask.get_existing_snapshot_aggregate_ids()
    |> Enum.reduce(%{}, fn [uuid, source], acc ->
      module = String.to_existing_atom(source)

      Map.put(acc, module, [uuid | Map.get(acc, module, [])])
    end)
  end

end
