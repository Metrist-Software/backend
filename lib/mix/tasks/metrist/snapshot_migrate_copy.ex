defmodule Mix.Tasks.Metrist.SnapshotMigrateCopy do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc "Copies snapshots previously generated through `Mix.Tasks.Metrist.SnapshotMigrate`"

  @opts [
    :env,
    {:aggregate, nil, :string, nil, "The specific aggregate to copy (Example: Elixir.Domain.Account, Elixir.Domain.StatusPage)"},
  ]

  @moduledoc """
  Copies snapshots previously generated through `Mix.Tasks.Metrist.SnapshotMigrate`
  from the migration EventStore into the active EventStore

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Helpers.configure(options.env)

    Mix.Task.run("app.config")

    Application.ensure_all_started(:postgrex)

    Mix.Shell.IO.yes?("Have you have run `mix metrist.snapshot_migrate` before proceeding?")
    |> do_copy(options)
  end

  defp do_copy(true, options) do
    Logger.info("Running snapshot copy")

    {:ok, conn} = Postgrex.start_link(Application.get_env(:backend, Backend.EventStore))

    select_statement = case options.aggregate do
      nil -> "SELECT * FROM migration.snapshots"
      value ->
        Logger.info("Copying all #{value} source_types")
        "SELECT * FROM migration.snapshots where source_type = '#{value}'"
    end

    Postgrex.transaction(conn, fn(conn) ->
      case options.aggregate do
        nil -> Postgrex.query!(conn, "TRUNCATE TABLE public.snapshots", [])
        value -> Postgrex.query!(conn, "DELETE FROM public.snapshots where source_type = '#{value}'", [])
      end
      Postgrex.query!(conn, "INSERT INTO public.snapshots #{select_statement}", [])
    end)

    Logger.info("Done")
  end

  defp do_copy(false, _options), do: Logger.info("Stopping snapshot copy")
end
