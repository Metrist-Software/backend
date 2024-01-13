defmodule Backend.ReleaseTasks do
  @moduledoc """
  Commands that are run during/from the release version. Mostly "work-arounds"
  for Mix not being present.
  """
  @app :backend
  require Logger

  def migrate do
    load_app()

    Logger.info("Migrating all regular repositories")
    for repo <- repos() do
      Logger.info("Migrating #{inspect repo}")
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def rollback_public do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(Backend.Repo, &Ecto.Migrator.run(&1, :down, step: 1, prefix: "public"))
  end

  def rollback_all_tenants do
    Logger.info("Rollback DBPA")
    load_app()

    # Can't call into dbpa.migrate mix task anymore as it will only function on local
    # builds now not a release build. It also runs Mix.Task.run("app.config") through
    # Helpers.start_repos which won't work in a release build
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:postgrex)
    {:ok, _} = Backend.Repo.start_link(pool_size: 10)
    Backend.Repo.rollback_all_tenants()
  end

  def init_es do
    load_app()
    config = Backend.EventStore.config()

    EventStore.Tasks.Init.exec(config, [])
    EventStore.Tasks.Migrate.exec(config, [])

    config = Backend.EventStore.Migration.config()
    EventStore.Tasks.Init.exec(config, [])
    EventStore.Tasks.Migrate.exec(config, [])
  end

  def migrate_es do
    Logger.info("Migrating event store")
    load_app()

    config = Backend.EventStore.config()
    EventStore.Tasks.Migrate.exec(config, [])

    config = Backend.EventStore.Migration.config()
    EventStore.Tasks.Migrate.exec(config, [])
  end

  def migrate_dbpa do
    Logger.info("Migrating DBPA")
    load_app()

    # Can't call into dbpa.migrate mix task anymore as it will only function on local
    # builds now not a release build. It also runs Mix.Task.run("app.config") through
    # Helpers.start_repos which won't work in a release build
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:postgrex)
    {:ok, _} = Backend.Repo.start_link(pool_size: 10)
    Backend.Repo.migrate_all_tenants()
  end

  def migrate_all do
    Logger.info("Migrating everything")
    migrate()
    migrate_es()
    migrate_dbpa()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
    |> Enum.filter(fn r -> r != Backend.TelemetryRepo end)
  end

  defp load_app do
    Application.ensure_all_started(:hackney)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:postgrex)
    Application.load(@app)
  end

end
