defmodule Backend.Notifications.HandlerTest do
  use ExUnit.Case, async: true

  alias Backend.Notifications.Handler
  alias Test.Support.Notifications.TestHandlers

  def make_event do
    %Domain.NotificationChannel.Events.Slack.DeliveryAttempted{
      id: "id",
      account_id: "account_id",
      alert_id: "alert_id",
      subscription_id: "subscription_id",
      channel_type: "this is not needed",
      channel_identity: "channel_identity",
      channel_extra_config: %{}}
  end

  test "requests can be skipped by the concrete handler" do
    event = make_event()
    alert = %Backend.Projections.Dbpa.Alert{is_instance_specific: true}

    commands = Handler.process_request(event, alert, Backend.Notifications.SlackHandler)

    assert commands == [%Domain.NotificationChannel.Commands.CompleteDelivery{alert_id: "alert_id", id: "id"}]
  end

  test "get a single successful response" do
    event = make_event()
    alert = %Backend.Projections.Dbpa.Alert{is_instance_specific: true}

    commands = Handler.process_request(event, alert, TestHandlers.SuccessfulSingleResponse)

    assert commands == [
      %Domain.NotificationChannel.Commands.CompleteDelivery{alert_id: "alert_id", id: "id"},
      %Domain.Account.Commands.AddSubscriptionDeliveryV2{
        status_code: 200, subscription_id: "subscription_id", alert_id: "alert_id", id: "account_id"}
    ]
  end

  test "get a single error response" do
    event = make_event()
    alert = %Backend.Projections.Dbpa.Alert{is_instance_specific: true}

    commands = Handler.process_request(event, alert, TestHandlers.ErrorSingleResponse)

    assert commands == [
      %Domain.NotificationChannel.Commands.RetryDelivery{alert_id: "alert_id", id: "id"},
      %Domain.Account.Commands.AddSubscriptionDeliveryV2{
        status_code: 500, subscription_id: "subscription_id", alert_id: "alert_id", id: "account_id"}
    ]
  end

  test "get multiple successful responses" do
    event = make_event()
    alert = %Backend.Projections.Dbpa.Alert{is_instance_specific: true}

    commands = Handler.process_request(event, alert, TestHandlers.SuccessfulMultiResponse)

    assert commands == [
      %Domain.NotificationChannel.Commands.CompleteDelivery{alert_id: "alert_id", id: "id"},
      %Domain.Account.Commands.AddSubscriptionDeliveryV2{
        status_code: 200, subscription_id: "subscription_id", alert_id: "alert_id", id: "account_id"}
    ]
  end

  test "get multiple errored responses" do
    event = make_event()
    alert = %Backend.Projections.Dbpa.Alert{is_instance_specific: true}

    commands = Handler.process_request(event, alert, TestHandlers.ErrorMultiResponse)

    assert commands == [
      %Domain.NotificationChannel.Commands.RetryDelivery{
        alert_id: "alert_id",
        id: "id"
      },
      %Domain.Account.Commands.AddSubscriptionDeliveryV2{
        status_code: 500, subscription_id: "subscription_id", alert_id: "alert_id", id: "account_id"}
    ]
  end

  test "A handler can implement it's own response validation" do
    event = make_event()
    alert = %Backend.Projections.Dbpa.Alert{is_instance_specific: true}
    commands = Handler.process_request(event, alert, TestHandlers.NonStandardResponse)

    assert commands == [
      %Domain.NotificationChannel.Commands.CompleteDelivery{alert_id: "alert_id", id: "id"},
      %Domain.Account.Commands.AddSubscriptionDeliveryV2{
        status_code: 201, subscription_id: "subscription_id", alert_id: "alert_id", id: "account_id"}
    ]
  end
end
