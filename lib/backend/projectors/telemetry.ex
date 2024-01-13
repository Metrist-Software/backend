defmodule Backend.Projectors.Telemetry do
  use Commanded.Projections.Ecto,
    application: Backend.App,
    name: __MODULE__,
    repo: Backend.Repo,
    subscribe_to: "TypeStream.Elixir.Domain.Monitor.Events.TelemetryAdded",
    batch_size: 10,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  require Logger

  import Backend.Repo, only: [schema_name: 1]
  alias Backend.Projections
  alias Commanded.Event.FailureContext

  @max_retry 5

  project_batch(events, fn multi ->
    Enum.reduce(events, multi, fn {event, metadata}, m ->
      Ecto.Multi.run(m, {:get_monitor_instance, metadata.event_id}, fn repo, _changes ->
        result =
          repo.get_by(
            Projections.Dbpa.MonitorInstance,
            [
              monitor_logical_name: event.monitor_logical_name,
              instance_name: event.instance_name
            ],
            prefix: schema_name(event.account_id)
          )

        if result do
          {:ok, result}
        else
          {:error, :monitor_instance_not_found}
        end
      end)
      |> Ecto.Multi.update({:update_monitor_instance, metadata.event_id}, fn changes ->
        monitor_instance = Map.get(changes, {:get_monitor_instance, metadata.event_id})

        updated_checks =
          Map.put(monitor_instance.check_last_reports, event.check_logical_name, event.created_at)

        Ecto.Changeset.change(
          monitor_instance,
          check_last_reports: updated_checks,
          last_report: event.created_at
        )
      end)
    end)
  end)

  @impl true
  def error({:error, :monitor_instance_not_found}, event, %FailureContext{context: context}) do
    context = record_failure(context)

    case Map.get(context, :failures) do
      too_many when too_many >= @max_retry ->
        Logger.warn(fn -> "Skipping bad event, too many failures. Last event " <> inspect(event) end)

        :skip

      _ ->
        {:retry, :timer.seconds(2), context}
    end
  end

  def error({:error, error}, event, _failure_context) do
    Logger.error("Could not project event due to #{error}, skipping. #{inspect(event)}")
    :skip
  end

  @impl true
  def after_update_batch(events, _changes) do
    Logger.debug("Broadcast after update: #{inspect(events)}")

    for {event, metadata} <- events do
      Backend.PubSub.broadcast_to_topic_of!(
        event,
        %{event: event, metadata: metadata}
      )
    end

    :ok
  end

  defp record_failure(context) do
    Map.update(context, :failures, 1, fn failures -> failures + 1 end)
  end
end
