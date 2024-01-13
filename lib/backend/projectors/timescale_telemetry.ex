defmodule Backend.Projectors.TimescaleTelemetry do
  use Commanded.Projections.Ecto,
    application: Backend.App,
    name: __MODULE__,
    repo: Backend.TelemetryWriteRepo,
    subscribe_to: "TypeStream.Elixir.Domain.Monitor.Events.TelemetryAdded",
    batch_size: 10,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  require Logger

  @impl true
  def error({:error, _error}, event, _failure_context) do
    Logger.error("ERROR: could not project event in Timescale: #{inspect(event)}")
    :skip
  end

  project_batch(events, fn multi ->
    telemetries =
      Enum.flat_map(events, fn {e, metadata} ->
        case Map.get(metadata, "actor") do
          %{"kind" => "admin", "method" => "local_copy"} ->
            Logger.debug(
              "Skipping telemetry entry, actor is local_copy so already bulk inserted: #{inspect(e)}"
            )

            []

          _ ->
            [
              %{
                time: e.created_at,
                monitor_id: e.monitor_logical_name,
                check_id: e.check_logical_name,
                instance_id: e.instance_name,
                account_id: e.account_id,
                value: e.value / 1 # Need to make sure it's a float and didn't get converted to an int
              }
            ]
        end
      end)

    Ecto.Multi.insert_all(
      multi,
      :insert_all_telemetry,
      Backend.Projections.Telemetry.MonitorTelemetry,
      telemetries
    )
  end)

  @impl true
  def after_update_batch(events, _changes) do
    for {event, _metadata} <- events do
      Backend.MonitorAgeTelemetry.process_telemetry(event)
    end

    :ok
  end

  # Note that the "regular" Ecto projector also handles TelemetryAdded so that events land through that
  # route in after_update/3 and from there in Phoenix PubSub.
end
