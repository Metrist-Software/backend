defmodule Backend.Notifications.WebhookHandlerTest do
  use ExUnit.Case, async: true

  alias Backend.Notifications.WebhookHandler
  alias Backend.Projections.Dbpa.Alert

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
        affected_regions: ["us-west-123"]
      }

    def make_event(),
      do: %Domain.NotificationChannel.Events.Webhook.DeliveryAttempted{
        id: "channel id",
        account_id: "account id",
        channel_type: "webhook",
        channel_identity: "https://webhooks.example.com/",
        channel_extra_config: nil,
        alert_id: "alert id",
        subscription_id: "sub_id"
      }

    test "Basic request is built correctly" do
      alert = make_alert()
      event = make_event()
      request = WebhookHandler.make_request(event, alert)

      json_body =
        """
        {
          "AffectedChecks": [
            {
              "Instance": "us-west-123",
              "Name": "CheckOne"
            }
          ],
          "AffectedRegions": ["us-west-123"],
          "MonitorId": "monitor_id",
          "MonitorName": "MonitorName"
        }
        """
        |> String.replace(~r/\s/, "")

      assert %HTTPoison.Request{
               method: :post,
               url: "https://webhooks.example.com/",
             } = request
      assert request.body == json_body
      assert Map.has_key?(request.headers, "content-type")
      assert Map.has_key?(request.headers, "user-agent")
    end

    test "Request body is pascal case" do
      uglified_alert = Map.put(make_alert(), :affected_checks, [%{
        "bad_name" => "CheckOne",
        "bad_instance" => "an-instance"
      }])
      expected_jsonified_pascalcase_response = "{\"AffectedChecks\":[{\"BadInstance\":\"an-instance\",\"BadName\":\"CheckOne\"}],\"AffectedRegions\":[\"us-west-123\"],\"MonitorId\":\"monitor_id\",\"MonitorName\":\"MonitorName\"}"
      assert WebhookHandler.make_body(uglified_alert) == expected_jsonified_pascalcase_response
    end

    test "Additional headers are sent" do
      extra_config = %{
        AdditionalHeaders: %{"x-auth": "auth key", "S3cr3t": "supersecretsecret"}
      }
      alert = make_alert()
      event =
        make_event()
        |> Map.put(:channel_extra_config, extra_config)

      request = WebhookHandler.make_request(event, alert)

      assert Map.get(request.headers, :"x-auth") == "auth key"
      assert Map.get(request.headers, :S3cr3t) == "supersecretsecret"
    end

    test "Additional headers as JSON are sent as well" do
      extra_config = %{
        AdditionalHeaders: ~s/{"x-auth": "auth key", "S3cr3t": "supersecretsecret"}/
      }
      alert = make_alert()
      event =
        make_event()
        |> Map.put(:channel_extra_config, extra_config)

      request = WebhookHandler.make_request(event, alert)

      # Note that maps keys are strings now, but that does not matter for when we
      # convert the whole thing to HTTP headers.
      assert Map.get(request.headers, "x-auth") == "auth key"
      assert Map.get(request.headers, "S3cr3t") == "supersecretsecret"
      assert Map.get(request.headers, "content-type") == "application/json"
    end

    test "Correct options are set" do
      request = WebhookHandler.make_request(make_event(), make_alert())

      # It's important that we do everything right here, so we make the
      # correct options very explicit. These options are to protect ourselves
      # from funny behaviour on the other side (and should be in the docs)

      assert Keyword.get(request.options, :timeout, 5_000)
      assert Keyword.get(request.options, :recv_timeout, 5_000)
      assert Keyword.get(request.options, :follow_redirect, true)
      assert Keyword.get(request.options, :max_redirect, 3)
      assert Keyword.get(request.options, :max_body_length, 10240)
    end

    test "Process ONLY instance-specific alerts for webhook, skip all others" do
      alert =
        make_alert()
        |> Map.put(:is_instance_specific, false)
      event = make_event()
      assert WebhookHandler.make_request(event, alert) == :skip
    end
  end

  describe "Response translation" do
    test "success is :ok" do
      response = {:ok, %HTTPoison.Response{status_code: 200}}
      assert Backend.Notifications.Handler.response_ok?(response) == true

      response = {:ok, %HTTPoison.Response{status_code: 201}}
      assert Backend.Notifications.Handler.response_ok?(response) == true

      response = {:ok, %HTTPoison.Response{status_code: 202}}
      assert Backend.Notifications.Handler.response_ok?(response) == true
    end

    # We always retry on a non-successful response
    test "4xx errors are :error" do
      response = {:ok, %HTTPoison.Response{status_code: 412}}
      assert Backend.Notifications.Handler.response_ok?(response) == false
    end

    test "5xx errors are :error" do
      response = {:ok, %HTTPoison.Response{status_code: 500}}
      assert Backend.Notifications.Handler.response_ok?(response) == false
    end

    test ":error results are, of course, :error" do
      response = {:error, nil}
      assert Backend.Notifications.Handler.response_ok?(response) == false
    end
  end
end
