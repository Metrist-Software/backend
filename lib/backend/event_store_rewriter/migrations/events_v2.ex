defmodule Backend.EventStoreRewriter.Migrations.EventsV2 do
  use Backend.EventStoreRewriter.Migration,
    name: "v2",
    app: Backend.App

  drop(Domain.Account.Events.SnapshotStored)

  drop(Domain.Clock.Ticked, fn re, _state ->
    cutoff = DateTime.utc_now()
      |> DateTime.add(-365, :day)
      |> DateTime.to_unix()
      |> div(60)

    re.data.value < cutoff
  end)

  drop(Domain.Monitor.Events.TelemetryAdded, fn re, _state ->
    NaiveDateTime.compare(cutoff(), re.data.created_at) == :gt
  end)

  drop(Domain.Monitor.Events.EventsCleared, fn re, _state ->
    NaiveDateTime.compare(cutoff(), re.data.end_time) == :gt
  end)

  @impl true
  def after_append_batch_to_stream(batch, migration, conn) do
    Enum.each(batch, fn event ->
      %event_type{} = event.data
      typestream = Backend.Projectors.TypeStreamLinker.event_type_to_stream(event_type)

      :ok =
        migration.event_store().link_to_stream(typestream, :any_version, [event.event_id],
          name: migration.name(),
          conn: conn
        )
    end)
  end

  defp cutoff,
    do:
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-365, :day)

end
