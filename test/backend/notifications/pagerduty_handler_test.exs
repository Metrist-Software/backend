defmodule Backend.Notifications.PagerDutyHandlerTest do
  use ExUnit.Case, async: true

  alias Backend.Notifications.PagerDutyHandler
  alias Backend.Projections.Dbpa.Alert
  alias Domain.NotificationChannel.Events.PagerDuty.DeliveryAttempted

  describe "Request building" do
    def make_alert(),
      do: %Alert{
        id: "alert id",
        state: :down,
        is_instance_specific: true,
        monitor_logical_name: "monitor_id",
        monitor_name: "MonitorName",
        affected_checks: [
          %{
            "Name" => "CheckOne",
            "Instance" => "us-west-123"
          }
        ],
        affected_regions: ["us-west-123"],
        correlation_id: "some-random-correlation-uuid"
      }

    def make_event(),
      do: %DeliveryAttempted{
        id: "channel id",
        account_id: "account id",
        channel_type: "pagerduty",
        channel_identity: "pd-routing-key",
        channel_extra_config: nil,
        alert_id: "alert id",
        subscription_id: "sub_id"
      }

    test "Notifications that aren't instance specific are skipped" do
      event = make_event()
      alert = make_alert()

      request = PagerDutyHandler.make_request(event, alert)
      refute request == :skip

      alert = %Alert{alert | is_instance_specific: false}
      request = PagerDutyHandler.make_request(event, alert)
      assert request == :skip
    end

    test "If the monitor is up and we autoresolve, we send a resolve" do
      event = make_event()
      alert = make_alert()

      alert = %Alert{alert | state: :up}
      event = %DeliveryAttempted{event | channel_extra_config: %{:AutoResolve => true}}

      request = PagerDutyHandler.make_request(event, alert)
      body = assert_valid_request(request, alert, event)
      assert Map.get(body, "event_action") == "resolve"
    end

    test "All other cases send a trigger" do
      event = make_event()
      alert = make_alert()

      alert = %Alert{alert | state: :down}
      event = %DeliveryAttempted{event | channel_extra_config: %{"AutoResolve" => "true"}}
      request = PagerDutyHandler.make_request(event, alert)
      body = assert_valid_request(request, alert, event)
      assert_valid_trigger_body(body, alert)

      # one top level test is enough, here we can test some variations
      assert "trigger" == PagerDutyHandler.event_action(true, false)
      assert "trigger" == PagerDutyHandler.event_action(false, true)
      assert "trigger" == PagerDutyHandler.event_action(false, false)
    end

    test "Trigger body has the correct severity" do
      # The general case got tested previously, so we focus on variations here.
      event = make_event()
      alert = make_alert()

      assert "error" == PagerDutyHandler.severity(event, alert)

      # For down, we take the down severity if it is set in the config, else a default.
      event = %DeliveryAttempted{event | channel_extra_config: %{:DownSeverity => "i-am-down"}}
      assert "i-am-down" == PagerDutyHandler.severity(event, alert)

      # Similarly, for degraded we can override
      alert = %Alert{state: :degraded}
      assert "warning" == PagerDutyHandler.severity(event, alert)

      event = %DeliveryAttempted{
        event
        | channel_extra_config: %{:DegradedSeverity => "i-am-sad"}
      }

      assert "i-am-sad" == PagerDutyHandler.severity(event, alert)

      # Anything else gets "info"
      alert = %Alert{state: :happy}
      assert "info" == PagerDutyHandler.severity(event, alert)
    end

    test "Trigger body has the correct summary" do
      alert = make_alert()

      # By default, we make one up from the event/alert data,
      assert "MonitorName is in a down state" == PagerDutyHandler.summary(alert)

      # ... unless we have one in the alert payload.
      alert = %Alert{
        alert
        | formatted_messages: %{
            "something" => "do not use me",
            "pagerduty" => "use me if you want to pager someone!"
          }
      }

      assert "use me if you want to pager someone!" == PagerDutyHandler.summary(alert)
    end

    defp assert_valid_request(request, alert, event) do
      assert Map.get(request.headers, "content-type", ~s(application/json; charset="utf-8"))
      assert request.method == :post
      assert String.contains?(request.url, "pagerduty.com")

      body = Jason.decode!(request.body)
      assert Map.get(body, "routing_key") == event.channel_identity
      assert Map.get(body, "dedup_key") == alert.correlation_id
      assert Map.has_key?(body, "event_action")

      # A bit of a hack, but in case a test wants to do more digging in the body, the
      # easier route.
      body
    end

    defp assert_valid_trigger_body(body, alert) do
      assert Map.get(body, "event_action") == "trigger"
      payload = Map.get(body, "payload")
      refute is_nil(payload)
      assert Map.get(payload, "source") == List.first(alert.affected_regions)
      assert Map.get(payload, "severity") == "error"
      assert Map.get(payload, "summary") == "MonitorName is in a down state"
    end
  end

  describe "Response translation" do
    # Left empty on purpose, as this is delegated to the Webhooks module.
  end
end
