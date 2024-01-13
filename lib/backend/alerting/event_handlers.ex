defmodule Backend.Alerting.EventHandlers do
  @moduledoc """
  Event handler for all alerting subsystem events.
  """
  require Logger

  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    start_from: :current,
    subscribe_to: Backend.Projectors.TypeStreamLinker.Helpers.type_stream(Domain.Account.Events.AlertDispatched)

  @impl true
  def handle(e = %Domain.Account.Events.AlertDispatched{}, metadata) do
    queue_notification(e.id, e.alert, metadata)
    :ok
  end

  defp queue_notification(account_id, alert, metadata) do
    subscriptions = Backend.Projections.Dbpa.Subscription.get_subscriptions_for_monitor(account_id, alert.monitor_logical_name)
    for subscription <- subscriptions do
      channel_id = Domain.NotificationChannel.Commands.make_channel_id(account_id, subscription)

      cmd = %Domain.NotificationChannel.Commands.QueueNotification{
        id: channel_id,
        channel_type: subscription.delivery_method,
        channel_identity: subscription.identity,
        channel_extra_config: subscription.extra_config,
        account_id: account_id,
        alert_id: alert.alert_id,
        generated_at: NaiveDateTime.from_iso8601!(alert.generated_at),
        subscription_id: subscription.id
      }

      Backend.App.dispatch_with_actor(Backend.Auth.Actor.backend_code(), cmd,
        causation_id: metadata.event_id,
        correlation_id: metadata.correlation_id
      )
    end
  end
end
