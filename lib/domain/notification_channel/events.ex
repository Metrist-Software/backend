defmodule Domain.NotificationChannel.Events do
  use TypedStruct

  typedstruct module: Created, enforce: true do
    plugin Backend.JsonUtils

    field :id, String.t()
    field :account_id, String.t()
    field :channel_type, String.t()
    field :channel_identity, String.t()
    field :channel_extra_config, %{String.t() => String.t()}
  end

  typedstruct module: NotificationQueued, enforce: true do
    plugin Backend.JsonUtils

    field :id, String.t()
    field :alert_id, String.t()
    field :subscription_id, String.t()
    field :generated_at, NaiveDateTime.t()
  end

  # This is a mild hack. Normally, we would carry the channel type inside the
  # event. However, by having it in the type, we can start a typed handler per
  # channel type, each with their own concurrency settings. This is helpful
  # as Slack will probably want us to not flood them while for URL webhook
  # delivery we can spam what we want. May be early optimization but events are
  # hard to change to better to overthink it a bit.
  @channel_map %{
    "slack" => Slack,
    "teams" => Teams,
    "email" => Email,
    "pagerduty" => PagerDuty,
    "webhook" => Webhook,
    "datadog" => Datadog
  }
  #@channel_types Map.keys(@channel_map)
  @attempt_types Enum.map(@channel_map, fn {_k, v} -> Module.concat([v, DeliveryAttempted]) end)
  def attempt_type(channel) when is_map_key(@channel_map, channel), do: Module.concat([__MODULE__, Map.get(@channel_map, channel), DeliveryAttempted])
  def attempt_type(channel), do: raise "Tried to retrieve DeliveryAttempted Type for channel not in channel map. #{channel}"

  for evt <- @attempt_types do
    typedstruct module: Module.concat(__MODULE__, evt), enforce: true do
      plugin Backend.JsonUtils

      field :id, String.t()
      field :account_id, String.t()
      field :alert_id, String.t()
      field :subscription_id, String.t() # Needed to record subscription delivery attempts against the subscription id
      field :channel_type, String.t() # Note - this is redundant - TODO verify&remove when all is done.
      field :channel_identity, String.t()
      field :channel_extra_config, %{String.t() => String.t()}
    end
  end

  for evt <- [DeliveryCompleted, RetryScheduled, DeliveryFailed] do
    typedstruct module: Module.concat(__MODULE__, evt), enforce: true do
      plugin Backend.JsonUtils

      field :id, String.t()
      field :alert_id, String.t()
    end
  end
 end
