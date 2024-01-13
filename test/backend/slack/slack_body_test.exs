defmodule Backend.Slack.SlackBodyTest do
  use ExUnit.Case, async: true

  @state_up :up
  @state_degraded :degraded
  @state_down :down
  @state_issues :issues
  @state_blocked :blocked

  require Logger

  alias Backend.Slack.SlackCommands
  alias Backend.Slack.SlashCommand
  alias Backend.Projections.Dbpa.{Monitor, Subscription, Snapshot}
  alias Backend.Slack.SlackBody
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail

  alias Test.Support.Slack.Helpers

  ##### testing for list_subscriptions #####

  test "list subscriptions" do
    subscriptions = [
      {Helpers.new_subscription("#first-channel"), Helpers.new_monitor("MonitorA")},
      {Helpers.new_subscription("#second-channel"), Helpers.new_monitor("MonitorB")},
      {Helpers.new_subscription("#third-channel"), Helpers.new_monitor("MonitorC")},
    ]
    body = SlackBody.list_subscriptions(subscriptions)

    assert body.response_type == "in_channel"
    assert Enum.count(body.blocks) == 3
    assert Enum.at(body.blocks, 0).text.text == "🔔 MonitorA in #first-channel"
    assert Enum.at(body.blocks, 1).text.text == "🔔 MonitorB in #second-channel"
    assert Enum.at(body.blocks, 2).text.text == "🔔 MonitorC in #third-channel"
  end

  test "too many subscriptions" do
    subscriptions = Helpers.new_subscription_list(46) # 45 is the cutoff
    body = SlackBody.list_subscriptions(subscriptions)

    assert List.last(body.blocks).text.text =~ "Sorry, we can't display all of your subscriptions."
  end

  test "no subscription response" do
    subscriptions = []
    body = SlackBody.list_subscriptions(subscriptions)

    assert body.response_type == "ephemeral"
    assert Enum.count(body.blocks) == 1
    assert Enum.at(body.blocks, 0).text.text =~ "No subscriptions found."
  end

  test "test subscribe response" do
    channel_name = "#fictitious-channel"
    body = SlackBody.subscribe_response(channel_name)
    assert body.response_type == "ephemeral"
    assert body.text == "Successfully subscribed #{channel_name} to alerts."
    end

  test "test unsubscribe response" do
    channel_name = "#fictitious-channel"
    body = SlackBody.unsubscribe_response(channel_name)
    assert body.response_type == "ephemeral"
    assert body.text == "Successfully unsubscribed #{channel_name} to alerts."
  end

  test "test notifications response" do
    body = SlackBody.notifications_response()
    assert body.response_type == "ephemeral"
    assert body.text == "Successfully subscribed to personal alerts."
  end

  ##### testing for choosing monitor #####

  test "choose monitor" do
    monitors = [
      Helpers.new_monitor("logical name", "name"),
      Helpers.new_monitor("logical name 2", "name2") ]
    body = SlackBody.choose_monitor(monitors)
    assert Enum.at(Enum.at(body.blocks, 0).accessory.options, 0).value == "logical name" # should be monitor id
    assert Enum.at(Enum.at(body.blocks, 0).accessory.options, 1).text.text == "name2 (logical name 2)"
  end

  test "choose monitor empty" do
    monitors = []
    body = SlackBody.choose_monitor(monitors)
    assert body.response_type == "ephemeral"
  end

  test "choose monitor nil" do
    monitors = nil
    body = SlackBody.choose_monitor(monitors)
    assert body.response_type == "ephemeral"
  end

  test "ask user to perform monitor selection" do
    body = SlackBody.ask_user_to_perform_monitor_selection()
    assert body.response_type == "ephemeral"
    assert Enum.at(body.blocks, 0).text.text =~ "You have no dependencies selected in your account"
  end

  ##### testing choosing subscriptions #####

  test "choose subscriptions" do
    mon1 = Helpers.new_monitor("MonitorA")
    mon1 = %Monitor{mon1 | logical_name: "test1"}
    monitors = [
      mon1,
      Helpers.new_monitor("MonitorB"),
      Helpers.new_monitor("MonitorC") ]
    sub1 = Helpers.new_subscription("sub1")
    sub1 = %Subscription{sub1 | monitor_id: "test1"}
    existing_subscriptions = [
      sub1,
      Helpers.new_subscription("sub2") ]
    channel_name = "#test-channel"
    body = SlackBody.choose_subscriptions(monitors, existing_subscriptions, channel_name)

    assert Enum.at(body.blocks, 0).accessory.type == "multi_static_select"
  end

  test "choose subscriptions with no existing subscriptions" do
    mon1 = Helpers.new_monitor("MonitorA")
    mon1 = %Monitor{mon1 | logical_name: "test1"}
    monitors = [
      mon1,
      Helpers.new_monitor("MonitorB"),
      Helpers.new_monitor("MonitorC") ]
    existing_subscriptions = []
    channel_name = "#test-channel"
    body = SlackBody.choose_subscriptions(monitors, existing_subscriptions, channel_name)
    assert Enum.at(body.blocks, 0).accessory.type == "multi_static_select"
  end

  ##### testing choosing notifications #####

  test "choose notifications" do
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    existing_subscriptions = []
    body = SlackBody.choose_notifications(monitors, existing_subscriptions)
    assert Enum.at(Enum.at(body.blocks, 0).accessory.options, 0).value == "testing"
    assert Enum.at(Enum.at(body.blocks, 0).accessory.options, 0).text.text == "Testing"
  end

  test "choose notifications with subscriptions" do
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    sub1 = Helpers.new_subscription("sub1")
    sub1 = %Subscription{sub1 | monitor_id: "testing"}
    existing_subscriptions = [
      sub1,
      Helpers.new_subscription("sub2") ]
    body = SlackBody.choose_notifications(monitors, existing_subscriptions)

    assert Enum.at(Enum.at(body.blocks, 0).accessory.options, 0).value == "testing"
    assert Enum.at(Enum.at(body.blocks, 0).accessory.options, 0).text.text == "Testing"
    assert Enum.at(body.blocks, 0).accessory.initial_options != nil
  end

  test "choose notifications with no existing subscriptions" do
    mon1 = Helpers.new_monitor("MonitorA")
    mon1 = %Monitor{mon1 | logical_name: "test1"}
    monitors = [
      mon1,
      Helpers.new_monitor("MonitorB"),
      Helpers.new_monitor("MonitorC") ]
    existing_subscriptions = []
    body = SlackBody.choose_notifications(monitors, existing_subscriptions)
    assert Enum.at(body.blocks, 0).accessory.type == "multi_static_select"
  end

  ##### testing for snapshot list #####

  test "list snapshots" do
    snapshot = Helpers.new_snapshot(:up)
    monitor = %Monitor{logical_name: "testing", name: "Testing"}
    body = SlackBody.list_snapshots([{monitor, snapshot}], [])
    assert body.response_type == "in_channel"
  end

  test "list too many snapshots" do
    snapshot_list = Helpers.new_snapshot_list(46)
    body = SlackBody.list_snapshots(snapshot_list, [])
    assert body.response_type == "in_channel"
  end

  #### testing for alert message #####

  test "alert message" do
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(:up)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing"}
    body = SlackBody.alert_message(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))
    body_actions = Enum.at(body, Enum.count(body) - 1)

    assert body_actions.type == "actions"
    assert Enum.count(body_actions.elements) == 1
    assert Enum.at(body_actions.elements, 0).action_id == "show-monitor"
  end

  test "alert message state degraded" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details = [
      %CheckDetail{
        name: "First Check",
        check_id: "first",
        instance: "ca-central-1",
        state: @state_degraded,
        average: 668.852932,
        current: 425,
        message: "Degraded first check.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "First Check",
        check_id: "first",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        check_id: "second",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        check_id: "second",
        instance: "us-east-1",
        state: @state_degraded,
        average: 668.852932,
        current: 425,
        message: "Degraded second check.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
    ]
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_degraded)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}


    body = SlackBody.alert_message(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))


    assert Enum.at(body, 0).text.text |> String.ends_with?("Testing is in a degraded state.")

    assert Enum.at(body, 2).text.text == "*First Check*"
    assert Enum.at(Enum.at(body, 3).elements, 0).text |> String.starts_with?("🐢️ [ca-central-1] Degraded first check.")
    assert Enum.at(body, 5).text.text == "*second*"
    assert Enum.at(Enum.at(body, 6).elements, 0).text |> String.starts_with?("🐢️ [us-east-1] Degraded second check.")

    assert Enum.at(body, Enum.count(body) - 1).type == "actions"
  end


  test "alert message status page down" do

    check_details = [
      %CheckDetail{
        state: :up,
        name: "Check",
        check_id: "check2",
        message: "Status Page component is up",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      },
      %CheckDetail{
        state: :up,
        name: "Check",
        check_id: "check3",
        message: "Status Page component is up",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      },
      %CheckDetail{
        state: :down,
        name: "Check",
        check_id: "check",
        message: "Status Page component is down",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      }
    ]


    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_degraded)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details, status_page_component_check_details: check_details}

    body = SlackBody.alert_message(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))

    assert Enum.at(body, 0).text.text |> String.ends_with?("🐢️ Testing is experiencing some issues: in a degraded state.")

    assert Enum.at(Enum.at(body, 3).elements ,0).text |> String.starts_with?("🔥 [] Status Page component is down ⏱ *now*")


    assert Enum.at(body, Enum.count(body) - 1).type == "actions"
  end



  test "alert message status both errors" do

    check_details = [
      %CheckDetail{
        state: :up,
        name: "Check",
        check_id: "check2",
        message: "Status Page component is up",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      },
      %CheckDetail{
        state: :up,
        name: "Check",
        check_id: "check3",
        message: "Status Page component is up",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      },
      %CheckDetail{
        state: :down,
        name: "Check",
        check_id: "check",
        message: "Status Page component is down",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      }
    ]


    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_degraded)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", status_page_component_check_details: check_details}

    body = SlackBody.alert_message(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))


    assert Enum.at(body, 0).text.text |> String.ends_with?("Testing just updated their status page: in a degraded state.")

    assert Enum.at(Enum.at(body, 3).elements ,0).text |> String.starts_with?("⭕ Status Page component is down -> down")


    assert Enum.at(body, Enum.count(body) - 1).type == "actions"
  end

  test "check_instance_cutoff_exeeded? returns true if either status_page_component_check_details and check_details is above the cutoff" do
    check = %CheckDetail{
        check_id: "second",
        instance: "us-east-1",
        state: :down
    }
    assert Backend.Slack.SlackBody.check_instance_cutoff_exceeded?([check], %{"check" => [check, check]}, 3, fn _details -> true end) == false
    assert Backend.Slack.SlackBody.check_instance_cutoff_exceeded?([check], %{"check" => [check, check]}, 1, fn _details -> true end) == true

    assert Backend.Slack.SlackBody.check_instance_cutoff_exceeded?([check, check, check], %{"check" => [check, check]}, 1, fn _details -> true end) == true
  end

  #### testing for snapshot #####

  test "snapshot" do
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(:up)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing"}
    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))
    body_actions = Enum.at(body.blocks, Enum.count(body.blocks) - 1)

    assert body.response_type == "in_channel"
    assert body_actions.type == "actions"
    assert Enum.at(body_actions.elements, 0).action_id == "show-details"
    assert Enum.at(body_actions.elements, 1).action_id == "show-monitor"
  end

  test "snapshot blocks only" do
    check_details = []
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(:up)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}
    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), blocks_only: true)

    assert Map.has_key?(body, :response_type) == false
    assert Enum.at(body.blocks, 0).text.text == "🎉 Testing is up and running."
    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot no monitor" do
    snapshot = Helpers.new_snapshot(:up)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing"}
    body = SlackBody.snapshot(snapshot, nil)

    assert Enum.at(body.blocks, 0).text.text == "🎉 testing is up and running."
    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot state up" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details = [
      %CheckDetail{
        name: "First Check",
        check_id: "first",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "First Check",
        check_id: "first",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "Second Check",
        check_id: "second",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "Second Check",
        check_id: "second",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
    ]
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(:up)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}
    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))

    assert Enum.at(body.blocks, 0).text.text == "🎉 Testing is up and running."
    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot state degraded" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details = [
      %CheckDetail{
        name: nil,
        check_id: "first",
        instance: "ca-central-1",
        state: @state_degraded,
        average: 668.852932,
        current: 425,
        message: "Degraded first check.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: nil,
        check_id: "first",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "Second Check",
        check_id: "second",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "Second Check",
        check_id: "second",
        instance: "us-east-1",
        state: @state_degraded,
        average: 668.852932,
        current: 425,
        message: "Degraded second check.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
    ]
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_degraded)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}
    # uses the default option to get order of check ids by calling get_check_ids_order_by_check_details(check_details_list)
    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), [now: fake_now, show_details: true])

    assert Enum.at(body.blocks, 0).text.text |> String.ends_with?("Testing is in a degraded state.")

    assert Enum.at(body.blocks, 2).text.text == "*first*"
    assert Enum.at(Enum.at(body.blocks, 3).elements, 0).text == "🐢️ [ca-central-1] *Degraded first check.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, 5).text.text == "*Second Check*"
    assert Enum.at(Enum.at(body.blocks, 6).elements, 0).text == "🐢️ [us-east-1] *Degraded second check.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot state down" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details = [
      %CheckDetail{
        name: "First Check",
        check_id: "first",
        instance: "ca-central-1",
        state: @state_down,
        average: 668.852932,
        current: 425,
        message: "Down here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "First Check",
        check_id: "first",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "Second Check",
        check_id: "second",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "Second Check",
        check_id: "second",
        instance: "us-east-1",
        state: @state_down,
        average: 668.852932,
        current: 425,
        message: "Down here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
    ]
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_down)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}

    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), [now: fake_now, show_details: true])

    assert Enum.at(body.blocks, 0).text.text |> String.ends_with?("🛑 Testing is down.")

    assert Enum.at(body.blocks, 2).text.text == "*First Check*"
    assert Enum.at(Enum.at(body.blocks, 3).elements, 0).text == "🔥 [ca-central-1] *Down here in ca-central-1.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, 5).text.text == "*Second Check*"
    assert Enum.at(Enum.at(body.blocks, 6).elements, 0).text == "🔥 [us-east-1] *Down here in us-east-1.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot state partially down" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details = [
      %CheckDetail{
        name: "StartPipeline (first check)",
        check_id: "start",
        instance: "ca-central-1",
        state: @state_down,
        average: 668.852932,
        current: 425,
        message: "Down here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "StartPipeline (first check)",
        check_id: "start",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "RunMonitorWorkflow (second check)",
        check_id: "run",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "RunMonitorWorkflow (second check)",
        check_id: "run",
        instance: "us-east-1",
        state: @state_down,
        average: 668.852932,
        current: 425,
        message: "Down here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
    ]
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_issues)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}

    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), [now: fake_now, show_details: true])

    assert Enum.at(body.blocks, 0).text.text |> String.ends_with?("💥 Testing is partially down.")

    assert Enum.at(body.blocks, 2).text.text == "*StartPipeline (first check)*"
    assert Enum.at(Enum.at(body.blocks, 3).elements, 0).text == "🔥 [ca-central-1] *Down here in ca-central-1.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, 5).text.text == "*RunMonitorWorkflow (second check)*"
    assert Enum.at(Enum.at(body.blocks, 6).elements, 0).text == "🔥 [us-east-1] *Down here in us-east-1.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot state blocked" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details =
      [
        %CheckDetail{
          average: 365.3875294117647,
          check_id: "CreateIncident",
          current: 351.0,
          instance: "us-east-1",
          message: "CreateIncident is responding normally from us-east-1",
          name: "CreateIncident",
          state: @state_up,
          created_at: fake_now |> NaiveDateTime.add(-32, :second),
          last_checked: fake_now |> NaiveDateTime.add(-32, :second)
        },
        %CheckDetail{
          average: 821.8668548576806,
          check_id: "CheckForIncident",
          current: 1004.0,
          instance: "us-east-1",
          message: "CheckForIncident is responding normally from us-east-1",
          name: "CheckForIncident",
          state: @state_up,
          created_at: fake_now |> NaiveDateTime.add(-32, :second),
          last_checked: fake_now |> NaiveDateTime.add(-32, :second)
        },
        %CheckDetail{
          average: 120.56,
          check_id: "AnaylzeIncident",
          current: nil,
          instance: "us-east-1",
          message: "AnaylzeIncident from us-east-1 is degraded.",
          name: "AnaylzeIncident",
          state: @state_degraded,
          created_at: fake_now |> NaiveDateTime.add(-32, :second),
          last_checked: fake_now |> NaiveDateTime.add(-32, :second)
        },
        %CheckDetail{
          average: 789.5133966203257,
          check_id: "ReceiveWebhook",
          current: nil,
          instance: "us-east-1",
          message: "ReceiveWebhook is not currently responding from us-east-1 and is currently down.",
          name: "ReceiveWebhook",
          state: @state_down,
          created_at: fake_now |> NaiveDateTime.add(-32, :second),
          last_checked: fake_now |> NaiveDateTime.add(-32, :second)
        },
        %CheckDetail{
          average: 110.7329706717124,
          check_id: "ResolveIncident",
          current: 111.0,
          instance: "us-east-1",
          message: "ResolveIncident is responding normally from us-east-1",
          name: "ResolveIncident",
          state: @state_blocked,
          created_at: fake_now |> NaiveDateTime.add(-32, :second),
          last_checked: fake_now |> NaiveDateTime.add(-32, :second)
        }
      ]

    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_issues)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}

    # show details is set to default (i.e. false)
    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))

    assert Enum.at(body.blocks, 0).text.text |> String.ends_with?("💥 Testing is partially down.")

    assert Enum.at(body.blocks, 2).text.text == "*AnaylzeIncident*"
    assert Enum.at(Enum.at(body.blocks, 3).elements, 0).text |> String.starts_with?("🐢️ [us-east-1] *AnaylzeIncident from us-east-1 is degraded.*")

    assert Enum.at(body.blocks, 5).text.text == "*ReceiveWebhook*"
    assert Enum.at(Enum.at(body.blocks, 6).elements, 0).text |> String.starts_with?("🔥 [us-east-1] *ReceiveWebhook is not currently responding from us-east-1 and is currently down.*")

    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"

    # show details set to true
    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), show_details: true)

    assert Enum.at(body.blocks, 0).text.text |> String.ends_with?("💥 Testing is partially down.")

    assert Enum.at(body.blocks, 2).text.text == "*CreateIncident*"
    assert Enum.at(Enum.at(body.blocks, 3).elements, 0).text |> String.starts_with?("🎉 [us-east-1] *351ms* _(365.4ms avg)_")

    assert Enum.at(body.blocks, 5).text.text == "*CheckForIncident*"
    assert Enum.at(Enum.at(body.blocks, 6).elements, 0).text |> String.starts_with?("🎉 [us-east-1] *1004ms* _(821.9ms avg)_")

    assert Enum.at(body.blocks, 8).text.text == "*AnaylzeIncident*"
    assert Enum.at(Enum.at(body.blocks, 9).elements, 0).text |> String.starts_with?("🐢️ [us-east-1] *AnaylzeIncident from us-east-1 is degraded.*")

    assert Enum.at(body.blocks, 11).text.text == "*ReceiveWebhook*"
    assert Enum.at(Enum.at(body.blocks, 12).elements, 0).text |> String.starts_with?("🔥 [us-east-1] *ReceiveWebhook is not currently responding from us-east-1 and is currently down.*")

    assert Enum.at(body.blocks, 14).text.text == "*ResolveIncident*"
    assert Enum.at(Enum.at(body.blocks, 15).elements, 0).text |> String.starts_with?("🧱 [us-east-1] *ResolveIncident is responding normally from us-east-1*")

    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "snapshot check ids provided" do
    fake_now = NaiveDateTime.new!(2020, 1, 1, 12, 0, 0)
    check_details = [
      %CheckDetail{
        name: "StartPiping",
        check_id: "start",
        instance: "ca-central-1",
        state: @state_down,
        average: 668.852932,
        current: 425,
        message: "Down here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "StartPiping",
        check_id: "start",
        instance: "us-east-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "RunWork",
        check_id: "run",
        instance: "ca-central-1",
        state: @state_up,
        average: 668.852932,
        current: 425,
        message: "All good here in ca-central-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
      %CheckDetail{
        name: "RunWork",
        check_id: "run",
        instance: "us-east-1",
        state: @state_down,
        average: 668.852932,
        current: 425,
        message: "Down here in us-east-1.",
        created_at: fake_now |> NaiveDateTime.add(-32, :second),
        last_checked: fake_now |> NaiveDateTime.add(-32, :second)
      },
    ]
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_issues)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}
    check_ids = ["FakeCheckId", "start"]

    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), [now: fake_now, show_details: true, check_ids: check_ids])

    assert Enum.at(body.blocks, 0).text.text |> String.ends_with?("💥 Testing is partially down.")

    assert Enum.at(body.blocks, 2).text.text == "*FakeCheckId*"
    assert Enum.at(Enum.at(body.blocks, 3).elements, 0).text == "No data available"

    assert Enum.at(body.blocks, 5).text.text == "*StartPiping*"
    assert Enum.at(Enum.at(body.blocks, 6).elements, 0).text == "🔥 [ca-central-1] *Down here in ca-central-1.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, 8).text.text == "*RunWork*"
    assert Enum.at(Enum.at(body.blocks, 9).elements, 0).text == "🔥 [us-east-1] *Down here in us-east-1.* ⏱ *32* seconds ago"

    assert Enum.at(body.blocks, Enum.count(body.blocks) - 1).type == "actions"
  end

  test "list too many check instances" do
    check_details = for index <- 1..60 do
      %CheckDetail{
        name: "Check",
        check_id: "check",
        instance: "ca-central-#{index}",
        state: :up,
        average: 10.0,
        current: 10.0,
        message: "Check is responding normally from ca-central-#{index}.",
        created_at: NaiveDateTime.utc_now,
        last_checked: NaiveDateTime.utc_now
      }
    end
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_up)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "testing", check_details: check_details}

    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end), show_details: true)
    assert Enum.at(body.blocks, 3).elements |> Enum.count == 10
  end

  test "snapshot monitor not found" do
    monitors = [ Helpers.new_monitor("testing", "Testing") ]
    snapshot = Helpers.new_snapshot(@state_down)
    snapshot = %Snapshot.Snapshot{snapshot | monitor_id: "thisdoesnotexist"}

    body = SlackBody.snapshot(snapshot, Enum.find(monitors, fn m -> snapshot.monitor_id == m.logical_name end))
    assert Enum.at(body.blocks, 0).text.text == "🛑 thisdoesnotexist is down."
  end

  test "snapshot with status page component block" do
    monitor = Helpers.new_monitor("testing", "Testing")
    snapshot = Helpers.new_snapshot(@state_up)

    check_detail = %CheckDetail{
      state: :up,
      name: "Check",
      check_id: "check",
      message: "Status Page component is responding normally",
      created_at: NaiveDateTime.utc_now(),
      last_checked: NaiveDateTime.utc_now()
    }

    result =
      %Snapshot.Snapshot{
        snapshot
        | monitor_id: "testing",
          status_page_component_check_details: [check_detail]
      }
      |> SlackBody.snapshot(monitor, show_details: true)

    assert Enum.count(result.blocks, fn
            %{type: "context", elements: [%{text: text}]} ->
              String.contains?(text, check_detail.message)

            _ ->
              false
          end) == 1
  end

  test "snapshot with non up status_page_component_check_details will list those components even when details is false" do
    monitor = Helpers.new_monitor("testing", "Testing")
    snapshot = Helpers.new_snapshot(@state_up)

    check_detail = %CheckDetail{
      state: :down,
      name: "Check",
      check_id: "check",
      message: "Status Page component is down",
      created_at: NaiveDateTime.utc_now(),
      last_checked: NaiveDateTime.utc_now()
    }

    result =
      %Snapshot.Snapshot{
        snapshot
        | monitor_id: "testing",
          status_page_component_check_details: [check_detail]
      }
      |> SlackBody.snapshot(monitor, show_details: false)

    assert Enum.count(result.blocks, fn
            %{type: "context", elements: [%{text: text}]} ->
              String.contains?(text, check_detail.message)

            _ ->
              false
          end) == 1
  end

  test "snapshot with some non up status_page_component_check_details will list those components first when showing details" do
    monitor = Helpers.new_monitor("testing", "Testing")
    snapshot = Helpers.new_snapshot(@state_up)
    check_details = [
      %CheckDetail{
        state: :up,
        name: "Check",
        check_id: "check2",
        message: "Status Page component is up",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      },
      %CheckDetail{
        state: :up,
        name: "Check",
        check_id: "check3",
        message: "Status Page component is up",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      },
      %CheckDetail{
        state: :down,
        name: "Check",
        check_id: "check",
        message: "Status Page component is down",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      }
    ]

    result =
      %Snapshot.Snapshot{
        snapshot
        | monitor_id: "testing",
          status_page_component_check_details: check_details
      }
      |> SlackBody.snapshot(monitor, show_details: true)

    assert List.first(Enum.at(result.blocks, 3).elements).text == "⭕ Status Page component is down -> down"
  end

  test "maybe_metrist_last_checked/2 will only prepend blocks if last_checked is not ~N[1970-01-01 00:00:00]" do
    snapshot = Helpers.new_snapshot(@state_up)
    snapshot = %Snapshot.Snapshot{ snapshot | last_checked: ~N[1970-01-01 00:00:00]}

    assert SlackBody.maybe_metrist_last_checked([], snapshot) == []
  end

  ##### testing for monitor not found #####

  test "monitor not found" do
    monitors = [
      Helpers.new_monitor("logical name", "name"),
      Helpers.new_monitor("logical name 2", "name2") ]

    body = SlackBody.monitor_not_found(monitors)
    assert body.response_type == "ephemeral"
    assert Enum.at(body.blocks, 0).text.text =~ "Sorry, I don't recognize that command."
  end

  test "monitor not found no monitors" do
    monitors = []

    body = SlackBody.monitor_not_found(monitors)
    assert body.response_type == "ephemeral"
    assert Enum.at(body.blocks, 0).text.text =~ "You have no dependencies selected in your account"
  end

  ##### testing for help #####

  test "help" do
    sc = %SlashCommand{
      token: "test",
      team_id: "test",
      team_domain: "test",
      enterprise_id: "test",
      enterprise_name: "test",
      channel_id: "test",
      channel_name: "test",
      user_id: "user_id",
      username: "test",
      command: "/metrist",
      text: "help",
      response_url: "test",
      trigger_id: "test",
      account_id: "test"
      }
    body = SlackCommands.execute(sc)

    assert body.response_type == "ephemeral"
  end

  ### testing regex and channel name ###

  alias Backend.Slack.SlackHelpers.SlackChannelHelper
  test "regex matching" do
    assert SlackChannelHelper.is_channel_valid?(nil) == false
    assert SlackChannelHelper.is_channel_valid?("no") == false
    assert SlackChannelHelper.is_channel_valid?("<#c1234|general>") == true
    assert SlackChannelHelper.is_channel_valid?("<#C1234|general>") == true
  end

  test "get channel" do
    test_channel = "<#c1234|general>"
    assert SlackChannelHelper.get_channel(test_channel) == {"C1234", "#general"}
    test_channel2 = "<#c1234|>"
    assert SlackChannelHelper.get_channel(test_channel2) == {"C1234", nil}
  end

  ### testing slack signature ###

  test "slack signature" do
    timestamp = "1606411179"
    |> String.to_integer()
    signature = "v0=ba222f1742b7ef48f987e7c9c4a41fabb7ad87961e47832f986f109625125145"
    signing_secret = "01debeb9c7462b0f2f63cb893918eef6"

    body = "token=HxEhM6O0hOSURZuorSkHYJHk&team_id=T015X4DFJ6M&team_domain=canaryheadquarters&channel_id=C01AH2K4068&channel_name=engineering&user_id=U01BK2GSTTN&user_name=dave&command=%2Fcanary-dev&text=givemeheaders%21&api_app_id=A01FF069F9A&response_url=https%3A%2F%2Fhooks.slack.com%2Fcommands%2FT015X4DFJ6M%2F1531584498355%2FOcqSzrdaj9cXilVNRWnPpNzd&trigger_id=1537540797124.1201149528225.e3c6cea63d9556d9dd6cf09a5b83c21c"

    signed = :crypto.mac(:hmac, :sha256, signing_secret, "v0:#{timestamp}:#{body}")
    |> Base.encode16()
    |> String.downcase()
    assert "v0=#{signed}" == signature
  end

  describe "add_status_page_component_blocks/3" do
    setup do

      check_detail = %CheckDetail{
        state: :down,
        name: "Check",
        check_id: "check",
        message: "ComponentName",
        created_at: NaiveDateTime.utc_now(),
        last_checked: NaiveDateTime.utc_now()
      }

      %{check_detail: check_detail }
    end

    test "check details without instance don't show instance", %{
      check_detail: check_detail
    } do
      result =
        SlackBody.add_status_page_component_blocks([], [check_detail], [check_details_filter_fn: &(&1), monitor_name: "test-monitor"])

      individual_component_elements = Enum.at(result, 1).elements
      assert hd(individual_component_elements).text == "⭕ ComponentName -> down"
    end

    test "check details with instance show instance", %{
      check_detail: check_detail
    } do
      check_detail = Map.put(check_detail, :instance, "instance1")
      result =
        SlackBody.add_status_page_component_blocks([], [check_detail], [check_details_filter_fn: &(&1), monitor_name: "test-monitor"])

      individual_component_elements = Enum.at(result, 1).elements
      assert hd(individual_component_elements).text == "⭕ ComponentName - instance1 -> down"
    end
  end
end
