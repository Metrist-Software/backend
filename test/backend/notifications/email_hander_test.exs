defmodule Backend.Notifications.EmailHandlerTest do
  use ExUnit.Case, async: true

  alias Backend.Notifications.EmailHandler

  describe "Request building" do

    def make_alert(),
      do: %Backend.Projections.Dbpa.Alert{
        id: "alert id",
        state: :down,
        is_instance_specific: false,
        monitor_logical_name: "monitor_id",
        monitor_name: "MonitorName",
        affected_checks: [],
        affected_regions: [],
        formatted_messages: %{
          "email" => "Email alert message"
        }
      }

    def make_event(),
      do: %Domain.NotificationChannel.Events.Webhook.DeliveryAttempted{
        id: "channel id",
        account_id: "account id",
        channel_type: "email",
        channel_identity: "email@example.com",
        channel_extra_config: nil,
        alert_id: "alert id",
        subscription_id: "sub_id"
      }

    test "Basic request is built correctly" do
      alert = make_alert()
      event = make_event()
      request = EmailHandler.make_request(event, alert)

      assert match?(%ExAws.Operation.Query{
        action: :send_email,
        params: %{
          "Destination.ToAddresses.member.1" => "email@example.com"
        }
      }, request)

      assert String.contains?(request.params["Message.Body.Text.Data"], alert.formatted_messages["email"])
    end

    test "Process ONLY non-instance-specific alerts for email, skip all others" do
      alert = make_alert()
      |> Map.put(:is_instance_specific, true)

      event = make_event()
      assert EmailHandler.make_request(event, alert) == :skip
    end
  end
end
