# Domo

We use Domo to perform validation on the commands that we dispatch through
Commanded using middleware (see [here](../lib/domain/middleware/type_validation.ex)).

Domo seems to occasionally have issues with the build cache when the structs it
is used on have changes to them. This can be resolved by running:

```elixir
mix clean && mix compile
```

