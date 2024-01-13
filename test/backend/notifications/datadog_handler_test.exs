defmodule Backend.Notifications.DatadogHandlerTest do
  use ExUnit.Case, async: true

  alias Backend.Notifications.DatadogHandler
  alias Backend.Notifications.Handler
  alias Backend.Projections.Dbpa.Alert

  describe "Request building" do
    def make_alert(),
      do: %Alert{
        id: "alert id",
        state: :degraded,
        is_instance_specific: true,
        monitor_logical_name: "monitor_id",
        monitor_name: "MonitorName",
        affected_checks: [
          %{
            "check_id" => "check_id",
            "name" => "CheckOne",
            "instance" => "us-west-123",
            "state" => "degraded"
          }
        ],
        affected_regions: ["us-west-123"]
      }

    def make_event(),
      do: %Domain.NotificationChannel.Events.Datadog.DeliveryAttempted{
        id: "channel id",
        account_id: "account id",
        channel_type: "webhook",
        channel_identity: "apikey",
        channel_extra_config: %{
          DatadogSite: "us3",
          DegradedSeverity: "Critical",
        },
        alert_id: "alert id",
        subscription_id: "sub_id"
      }

    test "Basic request is built correctly" do
      alert = make_alert()
      event = make_event()
      requests = DatadogHandler.make_request(event, alert)

      json_body =
        """
        {
          "check": "metrist.monitor.status",
          "host_name": "us-west-123",
          "status": 2,
          "tags": ["monitor:monitor_id", "check:check_id"]
        }
        """
        |> String.replace(~r/\s/, "")

      assert [%HTTPoison.Request{
               method: :post,
               url: "https://api.us3.datadoghq.com/api/v1/check_run",
             }] = requests

      request = List.first(requests)
      assert request.body == json_body
      assert Map.has_key?(request.headers, "content-type")
      assert Map.has_key?(request.headers, "user-agent")
      assert Map.get(request.headers, "DD-API-KEY") == event.channel_identity
    end

    test "Process ONLY instance-specific alerts for datadog, skip all others" do
      alert =
        make_alert()
        |> Map.put(:is_instance_specific, false)
      event = make_event()
      assert DatadogHandler.make_request(event, alert) == :skip
    end
  end

  describe "Default Response validation" do
    test "success is :ok" do
      response = {:ok, %HTTPoison.Response{status_code: 200}}
      assert Handler.response_ok?([response]) == true

      response = {:ok, %HTTPoison.Response{status_code: 201}}
      assert Handler.response_ok?([response]) == true

      response = {:ok, %HTTPoison.Response{status_code: 202}}
      assert Handler.response_ok?([response]) == true
    end

    # We always retry on a non-successful response
    test "4xx errors are :error" do
      response = {:ok, %HTTPoison.Response{status_code: 412}}
      assert Handler.response_ok?([response]) == false
    end

    test "5xx errors are :error" do
      response = {:ok, %HTTPoison.Response{status_code: 500}}
      assert Handler.response_ok?([response]) == false
    end

    test ":error results are, of course, :error" do
      response = {:error, nil}
      assert Handler.response_ok?([response]) == false
    end
  end
end
