defmodule Domain.NotificationChannel.Commands do
  use TypedStruct

  typedstruct module: QueueNotification, enforce: true do
    @moduledoc """
    A command to queue up a notification, which basically means "sending an alert to
    a subscription". We keep the subscription in its "fat" form, because we want to pool
    sending based on the actual type/id/extra_config values instead of the subscription id,
    but we only keep the alert id from the payload as we already have the payload in the event
    log and the projection database, replicating it would just add a lot of data storage for
    no value.
    """
    use Domo
    field :id, String.t()
    field :account_id, String.t()
    field :channel_type, String.t()
    field :channel_identity, String.t()
    field :channel_extra_config, %{optional(String.t()) => term()}
    field :alert_id, String.t()
    field :subscription_id, String.t()
    field :generated_at, NaiveDateTime.t()
  end

  typedstruct module: AttemptDelivery, enforce: true do
    use Domo
    field :id, String.t()
    field :alert_id, String.t()
    field :subscription_id, String.t()
  end

  for cmd <- [CompleteDelivery, RetryDelivery, FailDelivery] do
    typedstruct module: Module.concat(__MODULE__, cmd), enforce: true do
      use Domo
      field :id, String.t()
      field :alert_id, String.t()
    end
  end

  @type subscription :: %{id: String.t(),
                          delivery_method: String.t(),
                          identity: String.t(),
                          extra_config: %{String.t() => String.t()}}

  @doc """
  Given an account id and subscription data, return a channel id. By mixing in what makes a subscription
  really unique ("where does it go?"), we have stable notification channel ids so routing and thus
  serialization/concurrency works as intended.

  The account id is tossed in there to ensure that even if different accounts are sending to the
  exact same channel, they still get treated seperately.
  """
  @spec make_channel_id(String.t(), subscription()) :: String.t()
  def make_channel_id(account_id, subscription) do
    uniqueness_data = {
      subscription.delivery_method,
      subscription.identity,
      subscription.extra_config
    }
    uniqueness_key = :binary.decode_unsigned(:crypto.hash(:sha3_224, :erlang.term_to_binary(uniqueness_data)))
    uniqueness_key = Base62.encode(uniqueness_key)
    "#{account_id}_#{uniqueness_key}"
  end
end
