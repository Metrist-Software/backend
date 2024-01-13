# Snapshot Migration

When the structure of a Commanded aggregate needs to be changed, any snapshots
for it will need to be completely regenerated. Since this process can potentially
take multiple hours, it's impractical to have them be regenerated on the fly by
the production app. Instead, they should be pre-generated locally before deploying
a PR with these changes.

## Generating snapshots

Note: If you've never done this locally you likely won't have an event store "migrations"
schema setup. You can run `mix event_store.create -e Backend.EventStore.Migration` and then
`mix event_store.setup -e Backend.EventStore.Migration` to set it up.

Before deploying an aggregate change, new snapshots should be pre-generated. This
can be done by first increasing the `snapshot_version` value of the changed
aggregate of the `Commanded.Application` config in [app.ex](../lib/backend/app.ex)

Environment variables will be set by the standard mix helpers based on the passed
in value for env (or -e)

```
local:
mix metrist.snapshot_migrate -e local

deployed:
MIX_ENV=prod mix metrist.snapshot_migrate -e dev1
```

This will query all existing snapshots and generate up to date ones. Only aggregates
whose `snapshot_version` has changed will be completely rebuilt; others will be
built from a valid snapshot. This will likely take a while, but once this completes
you can verify the generated snapshots in the `migration.snapshots` table of the
eventstore database.

## Updating snapshots

Post deploy, you will need to copy the generated snapshots from the `migration`
schema to the active `public` schema's snapshot table. With your environment
variable correctly set as above, this can be done with the following:

```
local:
mix metrist.snapshot_migrate_copy -e local

deployed:
MIX_ENV=prod mix metrist.snapshot_migrate_copy -e dev1
```

## Troubleshooting

1. If you are running this on dev1 or prod and there is a new event in the event_store that
your branch does not have, it will fail snapshot generation for the impacted aggregate
(if it has to regenerate that aggregate)
