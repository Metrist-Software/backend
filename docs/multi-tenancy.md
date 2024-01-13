# Multi-tenancy

We employ a database per account using PostgreSQL schemas. Most of the code to
handle this has been stashed in [the Repo code](../lib/backend/repo.ex) where
account databases can be created and migrated.

A shared database exists under the default PostgreSQL schema `public`. Account
databases live in schemas starting with `dbpa_`.

## Creating a migration

For migrations, a dummy repo has been created so that the migration lands in the
correct spot. To create a migration for all account databases, do:

```
mix ecto.gen.migration <migration_name> -r Backend.DbpaRepo
```

This will make Ecto put the migration not in `priv/repo/migrations` but
in `priv/dbpa_repo/migrations` so we can keep them apart. When an account
database is migrated, this is where we make Ecto look for migrations.

## Running migrations

If you want to migrate all tenant databases in development, just do

```
mix dbpa.migrate
```

For the staging environment ("dev1"), this becomes

```
make migrate
```

And to migrate all of production, use

```
make migrate_prod
```

## Querying

Make sure that on all queries, you pass a `:prefix` option with the value
generated from `Ecto.Repo.schema_name(<account_id>)`. There is a ton of examples
in the code.
