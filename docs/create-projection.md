# Create a projection

## Ecto part

Our projections are through Ecto, and we leverage some (but not all) of Phoenix' built-in utilities and design patterns.

To start, generate code using `phx.gen.context` in the "Projections" context:

    mix phx.gen.context Projections User users id:string account_id:string email:string

This generates mostly correct code but we need to tweak things a bit:

1. We don't write through the context module, so remove all the update code from `lib/backend/projections.ex` so that only
   the `get_` and `list_` methods are left.

2. We manually set ids, so open up the generated schema class (`lib/backend/projections/<entity>.ex`) and add a
   `@primary_key {:id, :string, []}` above the `schema` statement to tell Ecto that primary keys are manual, and
   remove the `:id` field.

3. For the same reason, open up the generated migration file and add `primary_key: false` to the `table` arguments and
   add `primary_key: true` to the generated id field.

This sets up Ecto to correctly handle everything. `mix ecto.migrate` should now setup things for you. You can verify in
pgAdmin that the table was generated correct.

## Projector part

Open `lib/backend/projectors/ecto.ex` and add project methods for the events you want to handle. The code uses
`Ecto.multi/3` statements as return values because the Commanded Ecto projection library code will fold these
into a larger Ecto.multi transaction together with updating the last seen version for the projection; this way,
the library guarantees exactly-once processing from the point-of-view of the database.
