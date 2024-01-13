defmodule Backend.Notifications.SlackHandlerTest do
  use ExUnit.Case, async: true
  require Logger

  alias Backend.Notifications.SlackHandler

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
          "slack" => "Slack alert message"
        }
      }

    def make_event(),
      do: %Domain.NotificationChannel.Events.Webhook.DeliveryAttempted{
        id: "channel id",
        account_id: "account id",
        channel_type: "slack",
        channel_identity: "#test",
        channel_extra_config: %{WorkspaceId: nil},
        alert_id: "alert id",
        subscription_id: "sub_id"
      }

    test "Basic request is built correctly" do
      alert = make_alert()
      event = make_event()
      request = SlackHandler.make_request(event, alert)
      assert request.blocks == "Slack alert message"
    end

    test "Response works with invalid auth" do
      alert = make_alert()
      event = make_event()
      request = SlackHandler.make_request(event, alert)
      response = Backend.Integrations.Slack.post_message(request)
      assert Tuple.to_list(response) |> Enum.member?("invalid_auth")
    end

    test "Process ONLY non-instance-specific alerts for slack, skip all others" do
      alert = make_alert()
      |> Map.put(:is_instance_specific, true)

      event = make_event()
      assert SlackHandler.make_request(event, alert) == :skip
    end
  end

  describe "maybe_do_team_id_replacement/2" do
    test "--TEAM_ID-- with binary will be replaced with workspace id" do
      assert(
        SlackHandler.maybe_do_team_id_replacement("Slack alert message --TEAM_ID--", "test-workspace-id") == "Slack alert message test-workspace-id"
      )
    end

    test "--TEAM_ID-- with blocks will be replaced with workspace id" do
      assert(
        SlackHandler.maybe_do_team_id_replacement([%{ "message" => "Slack alert message --TEAM_ID--" }], "test-workspace-id") == [%{ "message" => "Slack alert message test-workspace-id" }]
      )
    end
  end
end
