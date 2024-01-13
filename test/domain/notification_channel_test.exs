defmodule Domain.NotificationChannelTest do
  use ExUnit.Case, async: true

  alias Domain.NotificationChannel
  alias Domain.NotificationChannel.{Commands, Events}

  defp make_queue_notification(),
    do: %Commands.QueueNotification{
      id: "channel id",
      channel_type: "webhook",
      channel_identity: "http://webhooks.example.com/123",
      channel_extra_config: %{"auth_key" => "456"},
      account_id: "account id",
      alert_id: "alert id",
      generated_at: ~N[2022-01-01 11:12:13],
      subscription_id: "sub_id"
    }

  defp make_created(),
    do: %Events.Created{
      id: "channel id",
      account_id: "account id",
      channel_type: "webhook",
      channel_identity: "http://webhooks.example.com/123",
      channel_extra_config: %{"auth_key" => "456"},
    }

  describe "QueueNotification" do
    test "Opens channel and queues notification" do
      cmd = make_queue_notification()

      chan = %NotificationChannel{}

      {_chan, events} =
        chan
        |> NotificationChannel.execute(cmd)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.at(events, 0) == make_created()
      assert %Events.NotificationQueued{id: "channel id", alert_id: "alert id"} =
               Enum.at(events, 1)
    end

    test "Subsequent queues only queue notification" do
      chan =
        %NotificationChannel{}
        |> NotificationChannel.apply(make_created())

      cmd = make_queue_notification()

      {_chan, events} =
        chan
        |> NotificationChannel.execute(cmd)
        |> Commanded.Aggregate.Multi.run()

      assert %Events.NotificationQueued{} = Enum.at(events, 0)
    end
  end

  describe "AttemptDelivery" do
    test "Emits event of the correct type" do
      chan =
        %NotificationChannel{}
        |> NotificationChannel.apply(make_created())

      cmd = %Commands.AttemptDelivery{
        id: "channel id",
        alert_id: "alert id",
        subscription_id: "sub_id"
      }

      evt = NotificationChannel.execute(chan, cmd)

      assert %Events.Webhook.DeliveryAttempted{
        id: "channel id",
        account_id: "account id",
        alert_id: "alert id",
        channel_type: "webhook",
        channel_identity: "http://webhooks.example.com/123",
        channel_extra_config: %{"auth_key" => "456"}
      } = evt
    end
  end

  describe "CompleteDelivery" do
    test "Emits event of the correct type" do
      chan =
        %NotificationChannel{}
        |> NotificationChannel.apply(make_created())

      cmd = %Commands.CompleteDelivery{
        id: "channel id",
        alert_id: "alert id"
      }

      evt = NotificationChannel.execute(chan, cmd)

      assert %Events.DeliveryCompleted{} = evt
    end
  end

  describe "RetryDelivery" do
    test "Emits correct event" do
      chan =
        %NotificationChannel{}
        |> NotificationChannel.apply(make_created())

      cmd = %Commands.RetryDelivery{id: "channel id", alert_id: "alert id"}

      evt = NotificationChannel.execute(chan, cmd)

      assert %Events.RetryScheduled{} = evt
    end
  end

  describe "FailDelivery" do
    test "Emits correct event" do
      chan =
        %NotificationChannel{}
        |> NotificationChannel.apply(make_created())

      cmd = %Commands.FailDelivery{id: "channel id", alert_id: "alert id"}

      evt = NotificationChannel.execute(chan, cmd)

      assert %Events.DeliveryFailed{} = evt
    end
  end
end
