defmodule Backend.Repo do
  use Ecto.Repo,
    otp_app: :backend,
    adapter: Ecto.Adapters.Postgres

  use Paginator
  # We also put our multitenancy stuff here for now.

  require Logger

  def schema_name(nil), do: "dbpa_SHARED"
  def schema_name(acct = %Backend.Projections.Account{}), do: schema_name(acct.id)
  def schema_name(id) when id != nil, do: "dbpa_#{id}"

  def migrations_path() do
    Path.join([Application.app_dir(:backend), "priv/dbpa_repo/migrations"])
  end

  def create_tenant(id) do
    prefix = schema_name(id)

    create_schema(prefix)
    migrate_schema(prefix)
  end

  def create_schema(prefix) do
    query(~s(CREATE SCHEMA "#{prefix}"))
    Ecto.Migration.SchemaMigration.ensure_schema_migrations_table!(__MODULE__, [], [])
  end

  def migrate_schema(prefix) do
    Logger.info("--- Migrating schema #{prefix}")
    options = [all: true, prefix: prefix]

    Ecto.Migrator.run(
      __MODULE__,
      migrations_path(),
      :up,
      options
    )
  end

  def rollback_schema(prefix) do
    Logger.info("--- Rolling back schema #{prefix}")
    options = [prefix: prefix, step: 1]

    Ecto.Migrator.run(
      __MODULE__,
      migrations_path(),
      :down,
      options
    )
  end

  def all_tenant_prefixes() do
    import Ecto.Query
    query =
      from(
        schemata in "schemata",
        select: schemata.schema_name,
        where: like(schemata.schema_name, ^"dbpa_%")
      )

    all(query, prefix: "information_schema")
  end

  def migrate_all_tenants() do
    create_tenant(nil)
    Enum.map(
      all_tenant_prefixes(),
      &migrate_schema/1
    )
  end

  def rollback_all_tenants() do
    Enum.map(
      all_tenant_prefixes(),
      &rollback_schema/1
    )
  end
end

# Dummy module so we can pass it to Ecto to generate migrations. It's
# pretty useless beyond that.
defmodule Backend.DbpaRepo do
  use Ecto.Repo,
    otp_app: :backend,
    adapter: Ecto.Adapters.Postgres
end
