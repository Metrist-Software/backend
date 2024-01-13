defmodule Backend.CommandedTelemetry do
  @moduledoc """
  PromEx module to report Commanded metrics. Directly reports the application dispatch
  and event handle telemetries for duration of command dispatches and duration of ecto projections.
  Also interpolates the time difference between an event's created at timestamp to the projection
  complete time to report projection lag (hopefully this will end up working, not as accurate as the
  direct commanded telemetry, but should still pick up bigger delays)
  """

  # A new Grafana dashboard has also been set up
  # at https://metrist.grafana.net/d/E4ZxHGm4z/backend-commanded-dashboard?orgId=1
  # as well as an alert on the lag metric

  use PromEx.Plugin

  @metric_prefix [:backend, :plugin, :commanded]

  @dispatch_stop_event [:commanded, :application, :dispatch, :stop]
  @event_handle_stop_event [:commanded, :event, :handle, :stop]

  @time_buckets [5, 10, 50, 100, 500, 1_000, 5_000, 10_000]

  @impl true
  def event_metrics(_opts) do
    [
      events()
    ]
  end

  defp events() do
    Event.build(
      :commanded_event_metrics,
      [
        distribution(
          @metric_prefix ++ [:dispatch, :duration],
          event_name: @dispatch_stop_event,
          measurement: :duration,
          description: "Time taken for a command to dispatch",
          reporter_options: [
            buckets: @time_buckets
          ],
          tag_values: fn metadata ->
            %name{} = metadata.execution_context.command
            %{command_name: to_string(name)}
          end,
          tags: [:command_name],
          unit: {:native, :millisecond}
        ),
        distribution(
          @metric_prefix ++ [:projection, :duration],
          event_name: @event_handle_stop_event,
          measurement: :duration,
          description: "Time taken for a projection to run",
          reporter_options: [
            buckets: @time_buckets
          ],
          tag_values: fn metadata ->
           %{event_name: metadata.recorded_event.event_type}
          end,
          keep: fn metadata ->
            metadata.handler_module == Backend.Projectors.Ecto
          end,
          tags: [:event_name],
          unit: {:native, :millisecond}
        ),
        distribution(
          @metric_prefix ++ [:projection, :lag],
          event_name: @event_handle_stop_event,
          measurement: fn _measurement, metadata ->
            # Not the most accurate measurement for this, but there doesn't seem to be any way to correlate
            # a given RecordedEvent between this and the other telemetries' metadata since they haven't been
            # stored in the db and/or assigned an ID at that point.
            # However, we want to alert when this value is in the multiple second range, and this
            # should be good enough for that level
            DateTime.diff(DateTime.utc_now(), metadata.recorded_event.created_at, :millisecond)
          end,
          description: "Time between an event being created and the projection being run",
          reporter_options: [
            buckets: @time_buckets
          ],
          tag_values: fn metadata ->
           %{event_name: metadata.recorded_event.event_type}
          end,
          keep: fn metadata ->
            metadata.handler_module == Backend.Projectors.Ecto
          end,
          tags: [:event_name],
          unit: {:native, :millisecond}
        )
      ]
    )
  end
end
