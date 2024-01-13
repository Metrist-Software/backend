defmodule Domain.NotificationChannel do
  @moduledoc """
  Notification Channels are what we send notifications to/through. They are
  account-specific and configuration specific (for example, each Slack workspace
  will have its own channel) to ensure that we can do fine-grained retries, etc.
  """

  @derive Jason.Encoder
  defstruct id: nil,
            account_id: nil,
            channel_type: nil,
            channel_identity: nil,
            channel_extra_config: %{}

  alias Commanded.Aggregate.Multi
  alias __MODULE__.{Commands, Events}

  import Domain.Helpers

  # Command handling

  def execute(nc = %__MODULE__{}, c = %Commands.QueueNotification{}) do
    nc
    |> Multi.new()
    |> Multi.execute(&maybe_create_channel(&1, c))
    |> Multi.execute(&queue_notification(&1, c))
  end

  def execute(nc = %__MODULE__{}, c = %Commands.AttemptDelivery{}) do
    c
    |> make_event(Events.attempt_type(nc.channel_type))
    |> Map.put(:account_id, nc.account_id)
    |> Map.put(:channel_type, nc.channel_type)
    |> Map.put(:channel_identity, nc.channel_identity)
    |> Map.put(:channel_extra_config, nc.channel_extra_config)
  end

  def execute(%__MODULE__{}, c = %Commands.CompleteDelivery{}) do
    make_event(c, Events.DeliveryCompleted)
  end

  def execute(%__MODULE__{}, c = %Commands.RetryDelivery{}) do
    make_event(c, Events.RetryScheduled)
  end

  def execute(%__MODULE__{}, c = %Commands.FailDelivery{}) do
    make_event(c, Events.DeliveryFailed)
  end

  # Event application

  def apply(nc, e = %Events.Created{}) do
    %__MODULE__{
      nc
      | id: e.id,
        account_id: e.account_id,
        channel_type: e.channel_type,
        channel_identity: e.channel_identity,
        channel_extra_config: e.channel_extra_config
    }
  end

  def apply(nc, _e), do: nc

  # Helpers

  defp maybe_create_channel(%__MODULE__{id: nil}, c) do
    %Events.Created{
      id: c.id,
      account_id: c.account_id,
      channel_type: c.channel_type,
      channel_identity: c.channel_identity,
      channel_extra_config: c.channel_extra_config
    }
  end

  defp maybe_create_channel(_nc, _c) do
    []
  end

  defp queue_notification(nc, c) do
    %Events.NotificationQueued{
      id: nc.id,
      alert_id: c.alert_id,
      generated_at: c.generated_at,
      subscription_id: c.subscription_id
    }
  end
end
