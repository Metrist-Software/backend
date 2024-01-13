defmodule Domain.AccountTest do
  use ExUnit.Case, async: true

  test "Setting visible monitors with no monitors selected" do
    acct = %Domain.Account{id: 42}
    cmd = %Domain.Account.Commands.SetVisibleMonitors{
      id: 42,
      monitor_logical_names: ["foo", "bar", "baz"]
    }

    evts = Domain.Account.execute(acct, cmd)

    assert_same evts, [
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "foo"},
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "bar"},
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "baz"},
    ]
  end

  test "Setting visible monitors with monitors selected emits delta" do
    acct = %Domain.Account{
      id: 42,
      visible_monitors: ["bar"]
    }
    cmd = %Domain.Account.Commands.SetVisibleMonitors{
      id: 42,
      monitor_logical_names: ["foo", "baz"]
    }

    evts = Domain.Account.execute(acct, cmd)

    assert_same evts, [
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "foo"},
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "baz"},
      %Domain.Account.Events.VisibleMonitorRemoved{id: 42, monitor_logical_name: "bar"}
    ]
  end

  test "Applying added monitors adds new monitors" do
    acct = %Domain.Account{
      visible_monitors: ["bar"]
    }
    evts = [
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "foo"},
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "bar"},
      %Domain.Account.Events.VisibleMonitorAdded{id: 42, monitor_logical_name: "baz"},
    ]

    acct = Enum.reduce(evts, acct, fn evt, acct ->
      Domain.Account.apply(acct, evt)
    end)

    assert_same acct.visible_monitors, ["bar", "baz", "foo"]
  end

  test "Applying removed monitors removes old monitors" do
    acct = %Domain.Account{
      visible_monitors: ["foo", "bar", "baz"]
    }
    evts = [
      %Domain.Account.Events.VisibleMonitorRemoved{id: 42, monitor_logical_name: "foo"},
      %Domain.Account.Events.VisibleMonitorRemoved{id: 42, monitor_logical_name: "baz"},
    ]

    acct = Enum.reduce(evts, acct, fn evt, acct ->
      Domain.Account.apply(acct, evt)
    end)

    assert acct.visible_monitors == ["bar"]
  end

  test "Adding a new user adds to the tracked users" do
    acct = %Domain.Account{
      id: 42,
      user_ids: ["foo", "bar"]
    }

    cmd = %Domain.Account.Commands.AddUser{
      id: 42,
      user_id: "baz"
    }

    evt = Domain.Account.execute(acct, cmd)
    assert evt == %Domain.Account.Events.UserAdded{id: 42, user_id: "baz"}

    acct = Domain.Account.apply(acct, evt)
    assert acct.user_ids == ["baz", "foo", "bar"]
  end

  test "Adding an existing user emits no event" do
    acct = %Domain.Account{
      id: 42,
      user_ids: ["foo", "bar", "baz"]
    }

    cmd = %Domain.Account.Commands.AddUser{
      id: 42,
      user_id: "baz"
    }

    evt = Domain.Account.execute(acct, cmd)
    assert is_nil(evt)
  end

  test "Removing an existing user removes them from the tracked users" do
    acct = %Domain.Account{
      id: 42,
      user_ids: ["foo", "bar"]
    }

    cmd = %Domain.Account.Commands.RemoveUser{
      id: 42,
      user_id: "bar"
    }

    evt = Domain.Account.execute(acct, cmd)
    assert evt == %Domain.Account.Events.UserRemoved{id: 42, user_id: "bar"}

    acct = Domain.Account.apply(acct, evt)
    assert acct.user_ids == ["foo"]
  end

  test "Removing a user not on the account emits no event" do
    acct = %Domain.Account{
      id: 42,
      user_ids: ["foo", "bar"]
    }

    cmd = %Domain.Account.Commands.RemoveUser{
      id: 42,
      user_id: "baz"
    }

    evt = Domain.Account.execute(acct, cmd)
    assert is_nil(evt)
  end

  test "ChooseMonitors when removing monitors should remove associated subscriptions" do
    mon = %Domain.Account{
      id: "test_account_id",
      subscriptions: [
        %Domain.Account.Subscription {
          id: "testsubscription_id",
          delivery_method: "slack",
          monitor_logical_name: "testsignal"
        },
        %Domain.Account.Subscription {
          id: "testsubscription_id2",
          delivery_method: "email",
          monitor_logical_name: "testsignal"
        },
        %Domain.Account.Subscription {
          id: "testsubscription_id3",
          delivery_method: "slack",
          monitor_logical_name: "eks"
        }
      ],
      monitors: [%Domain.Account.Monitor{
        logical_name: "testsignal"
      },
      %Domain.Account.Monitor{
        logical_name: "secondmonitor"
      }]
    }
    cmd = %Domain.Account.Commands.ChooseMonitors{
      id: "test_account_id",
      user_id: "test_user_id",
      add_monitors: [],
      remove_monitors: ["testsignal"]
    }

    {_account, events} =
      Domain.Account.execute(mon, cmd)
      |> Commanded.Aggregate.Multi.run()

    assert length(Enum.filter(events, fn
      %Domain.Account.Events.MonitorRemoved{} -> true
      _ -> false end)) == 1
    assert length(Enum.filter(events, fn
      %Domain.Account.Events.SubscriptionDeleted{} -> true
      _ -> false end)) == 2
  end

  test "SetMonitors will diff and emit appropriate events" do
    mon = %Domain.Account{
      id: "test_account_id",
      monitors: [%Domain.Account.Monitor{
        logical_name: "testsignal"
      },
      %Domain.Account.Monitor{
        logical_name: "secondmonitor"
      }]
    }
    cmd = %Domain.Account.Commands.SetMonitors{
      id: "test_account_id",
      monitors: [%Domain.Account.Commands.MonitorSpec{
        logical_name: "thirdmonitor",
        name: "Third monitor"
      }],
    }

    {account, _events} =
      Domain.Account.execute(mon, cmd)
      |> Commanded.Aggregate.Multi.run()

    assert length(account.monitors) == 1
    assert Enum.at(account.monitors, 0).logical_name == "thirdmonitor"
  end

  test "RemoveSlackWorkspace should remove slack subscriptions to workspace" do
    mon = %Domain.Account{
      id: "test_account_id",
      subscriptions: [
        %Domain.Account.Subscription {
          id: "testsubscription_id",
          delivery_method: "slack",
          monitor_logical_name: "testsignal",
          slack_workspace_id: "testworkspace1"
        },
        %Domain.Account.Subscription {
          id: "testsubscription_id2",
          delivery_method: "email",
          monitor_logical_name: "gmaps",
          slack_workspace_id: "testworkspace1"
        },
        %Domain.Account.Subscription {
          id: "testsubscription_id3",
          delivery_method: "email",
          monitor_logical_name: "eks"
        },
        %Domain.Account.Subscription {
          id: "testsubscription_id3",
          delivery_method: "slack",
          monitor_logical_name: "eks",
          slack_workspace_id: "testworkspace2"
        }
      ]
    }
    cmd = %Domain.Account.Commands.RemoveSlackWorkspace{
      id: "test_account_id",
      team_id: "testworkspace1"
    }

    {_account, events} =
      Domain.Account.execute(mon, cmd)
      |> Commanded.Aggregate.Multi.run()

    assert length(Enum.filter(events, fn
      %Domain.Account.Events.SubscriptionDeleted{} -> true
      _ -> false end)) == 2
  end

  test "Dispatching an alert will only send if there are matching subscriptions" do
    acct = %Domain.Account{
      id: 42,
      subscriptions: [%Domain.Account.Subscription{ monitor_logical_name: "testsignal" }]
    }

    cmd = %Domain.Account.Commands.DispatchAlert{
      id: 42,
      alert: %Domain.Account.Commands.Alert{
        alert_id: nil,
        generated_at: NaiveDateTime.utc_now(),
        affected_checks: [],
        affected_regions: [],
        formatted_messages: %{},
        is_instance_specific: false,
        state: :up,
        correlation_id: nil,
        monitor_logical_name: "testsignal"
      }
    }

    evt = Domain.Account.execute(acct, cmd)
    assert %Domain.Account.Events.AlertDispatched{} = evt
  end

  test "Dispatching an alert will not emit an event if there are no matching subscriptions" do
    acct = %Domain.Account{
      id: 42,
      subscriptions: []
    }

    cmd = %Domain.Account.Commands.DispatchAlert{
      id: 42,
      alert: %Domain.Account.Commands.Alert{
        alert_id: nil,
        generated_at: NaiveDateTime.utc_now(),
        affected_checks: [],
        affected_regions: [],
        formatted_messages: %{},
        is_instance_specific: false,
        state: :up,
        correlation_id: nil,
        monitor_logical_name: "testsignal"
      }
    }

    evt = Domain.Account.execute(acct, cmd)

    assert is_nil(evt)
  end

  defp assert_same(set1, set2), do: assert MapSet.new(set1) == MapSet.new(set2)
end
