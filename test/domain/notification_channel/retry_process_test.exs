defmodule Domain.NotificationChannel.RetryProcessTest do
  use ExUnit.Case, async: true

  alias Domain.NotificationChannel.{RetryProcess, Commands, Events}

  defp make_notification_queued(alert_id \\ "alert_id") do
    %Events.NotificationQueued{
      id: "channel id",
      alert_id: alert_id,
      generated_at: ~N[2022-01-01 11:12:13],
      subscription_id: "sub_id"
    }
  end

  defp make_created(),
    do: %Events.Created{
      id: "channel id",
      account_id: "account id",
      channel_type: "webhook",
      channel_identity: "http://example.com",
      channel_extra_config: %{}
    }

  describe "Created" do
    test "Is interested" do
      assert RetryProcess.interested?(make_created())
    end

    test "Just sets the id" do
      retry_proc = %RetryProcess{}
      evt = make_created()

      retry_proc = RetryProcess.apply(retry_proc, evt)
      assert retry_proc.id == "channel id"
    end
  end

  describe "NotificationQueued" do
    test "Is interested" do
      assert RetryProcess.interested?(make_notification_queued())
    end

    test "Initially immediately triggers delivery" do
      retry_proc = %RetryProcess{}
      evt = make_notification_queued()

      cmd = RetryProcess.handle(retry_proc, evt)

      assert %Commands.AttemptDelivery{} = cmd
    end

    test "If something is in flight, only queues" do
      retry_proc = %RetryProcess{current_notification: %{alert_id: "alert zero"}}
      evt = make_notification_queued()

      assert RetryProcess.handle(retry_proc, evt) == nil

      retry_proc = RetryProcess.apply(retry_proc, evt)
      assert %RetryProcess{queued_notifications: [%{alert_id: "alert_id"}]} = retry_proc
    end

    test "If something is already queued, queues it up" do
      retry_proc = %RetryProcess{queued_notifications: [%{alert_id: "alert zero"}]}
      evt = make_notification_queued()

      assert RetryProcess.handle(retry_proc, evt) == nil

      retry_proc = RetryProcess.apply(retry_proc, evt)

      assert %RetryProcess{
               queued_notifications: [%{alert_id: "alert zero"}, %{alert_id: "alert_id"}]
             } = retry_proc
    end
  end

  describe "DeliveryCompleted" do
    test "Is interested" do
      assert RetryProcess.interested?(%Events.DeliveryCompleted{
               id: "channel id",
               alert_id: "alert id"
             })
    end

    test "Clears current" do
      retry_proc = %RetryProcess{id: "channel id", current_notification: %{alert_id: "alert id"}}
      evt = %Events.DeliveryCompleted{id: "channel id", alert_id: "alert id"}

      retry_proc = RetryProcess.apply(retry_proc, evt)
      assert %RetryProcess{current_notification: nil} = retry_proc
    end

    test "Immediately schedules next" do
      retry_proc = %RetryProcess{
        id: "channel id",
        current_notification: %{alert_id: "alert one", subscription_id: "sub_id"},
        queued_notifications: [%{alert_id: "alert two", tries_left: 5, subscription_id: "sub_id"}]
      }

      evt = %Events.DeliveryCompleted{id: "channel id", alert_id: "alert one"}

      cmd = RetryProcess.handle(retry_proc, evt)

      assert %Commands.AttemptDelivery{
               id: "channel id",
               alert_id: "alert two"
             } = cmd

      retry_proc = RetryProcess.apply(retry_proc, evt)

      assert %RetryProcess{
               current_notification: %{alert_id: "alert two"},
               queued_notifications: []
             } = retry_proc
    end
  end

  describe "Queueing" do
    test "Only one notification in flight at a time" do
      retry_proc = %RetryProcess{id: "channel id"}

      # The first one is handled immediately
      evt1 = make_notification_queued("alert one")
      cmd = RetryProcess.handle(retry_proc, evt1)
      assert %Commands.AttemptDelivery{id: "channel id", alert_id: "alert one"} = cmd
      retry_proc = RetryProcess.apply(retry_proc, evt1)

      # The next one is queued
      evt2 = make_notification_queued("alert two")
      cmd = RetryProcess.handle(retry_proc, evt2)
      assert cmd == nil
      retry_proc = RetryProcess.apply(retry_proc, evt2)

      # And handled as soon as the previous one completes
      complete = %Events.DeliveryCompleted{id: "channel id", alert_id: "alert one"}
      cmd = RetryProcess.handle(retry_proc, complete)
      assert %Commands.AttemptDelivery{id: "channel id", alert_id: "alert two"} = cmd
      retry_proc = RetryProcess.apply(retry_proc, complete)

      # ...which empties the queue
      complete = %Events.DeliveryCompleted{id: "channel id", alert_id: "alert one"}
      assert RetryProcess.handle(retry_proc, complete) == nil
    end
  end

  describe "Clock Ticks" do
    test "With no work scheduled" do
      retry_proc = %RetryProcess{}
      evt = %Domain.Clock.Ticked{id: "minute-clock", value: -1}
      cmd = RetryProcess.handle(retry_proc, evt)

      assert cmd == nil
    end
  end

  describe "Retries" do
    test "Is interested" do
      assert RetryProcess.interested?(%Events.RetryScheduled{
               id: "channel id",
               alert_id: "alert id"
             }) == {:continue, "channel id"}
    end

    test "Triggers on next minute clock" do
      retry_proc =
        %RetryProcess{}
        |> RetryProcess.apply(make_notification_queued())

      evt = %Events.RetryScheduled{id: "channel id", alert_id: "alert id"}

      # Nothing happens immediately
      assert RetryProcess.handle(retry_proc, evt) == nil
      retry_proc = RetryProcess.apply(retry_proc, evt)

      # But on the clock tick, we execute the scheduled retry
      evt = %Domain.Clock.Ticked{id: "minute-clock", value: -1}
      cmd = RetryProcess.handle(retry_proc, evt)
      assert %Commands.AttemptDelivery{} = cmd
    end

    test "Five retries is the max" do
      retry_proc =
        RetryProcess.apply(
          %RetryProcess{id: "channel id"},
          make_notification_queued("alert one")
        )

      # This is a bit more verbose than strictly necessary, but kept
      # this way to make things easy to follow. Note that per the
      # first test in this file, the above triggered delivery so the process
      # is now waiting for a result

      retry_evt = %Events.RetryScheduled{id: "channel id", alert_id: "alert one"}
      tick_evt = %Domain.Clock.Ticked{id: "minute_clock", value: -1}

      # First retry. All retries wait for a clock tick.
      assert RetryProcess.handle(retry_proc, retry_evt) == nil
      retry_proc = RetryProcess.apply(retry_proc, retry_evt)
      cmd = RetryProcess.handle(retry_proc, tick_evt)
      assert %Commands.AttemptDelivery{id: "channel id", alert_id: "alert one", subscription_id: "sub_id"} == cmd
      retry_proc = RetryProcess.apply(retry_proc, tick_evt)

      # Fast forward a couple of retries, just the state changes to move the
      # process to the point where it'll fail.
      retry_proc = RetryProcess.apply(retry_proc, retry_evt)
      retry_proc = RetryProcess.apply(retry_proc, tick_evt)
      retry_proc = RetryProcess.apply(retry_proc, retry_evt)
      retry_proc = RetryProcess.apply(retry_proc, tick_evt)
      retry_proc = RetryProcess.apply(retry_proc, retry_evt)
      retry_proc = RetryProcess.apply(retry_proc, tick_evt)
      retry_proc = RetryProcess.apply(retry_proc, retry_evt)
      retry_proc = RetryProcess.apply(retry_proc, tick_evt)

      # Final retry, we fail
      cmd = RetryProcess.handle(retry_proc, retry_evt)
      assert %Commands.FailDelivery{id: "channel id", alert_id: "alert one"} = cmd
      retry_proc = RetryProcess.apply(retry_proc, retry_evt)
      # Nothing queued, nothing current
      assert %RetryProcess{current_notification: nil, queued_notifications: []} = retry_proc
    end
  end
end
