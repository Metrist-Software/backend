defmodule Backend.RealTimeAnalytics.MonitorEventsTest do
  use ExUnit.Case, async: true
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail
  alias Domain.Monitor.Commands.EndEvent
  alias Domain.Monitor.Commands.AddEvent
  alias Backend.RealTimeAnalytics

  describe "process_events/4" do
    @common_opts [account_id: "test_account", monitor_id: "test_monitor"]

    test "Creates AddEvent on state transition" do
      check_details_1 = []

      check_details_2 = [
        %CheckDetail{
          check_id: "check_id_1",
          instance: "instance1",
          state: :down,
          last_checked: ~N[2020-03-11 23:00:07]
        }
      ]

      {_, cmds} =
        RealTimeAnalytics.MonitorEvents.process_events(
          check_details_1,
          check_details_2,
          [],
          Keyword.merge(@common_opts, new_snapshot_state: :down)
        )

      assert match?([%AddEvent{check_logical_name: "check_id_1"}], cmds)
    end

    test "Creates EndEvent and AddEvent cmd if state transitioned" do
      check_details_1 = [
        %CheckDetail{check_id: "check_id_1", instance: "instance1", state: :down}
      ]

      check_details_2 = [
        %CheckDetail{
          check_id: "check_id_1",
          instance: "instance1",
          state: :up,
          last_checked: ~N[2020-03-11 23:00:07]
        }
      ]

      outstanding_events = [
        {"event_id_1", "check_id_1", "instance1", "corr_id_1", :down}
      ]

      {new_outstanding_events, cmds} =
        RealTimeAnalytics.MonitorEvents.process_events(
          check_details_1,
          check_details_2,
          outstanding_events,
          Keyword.merge(@common_opts, new_snapshot_state: :down)
        )

      assert match?(
               [
                 # Ends outstanding event for check_id_1
                 %EndEvent{monitor_event_id: "event_id_1"},
                 # Creates a new event for check_id_1
                 %AddEvent{check_logical_name: "check_id_1"}
               ],
               cmds
             )

      # Assert that the old outstanding event is deleted because of state transition
      assert new_outstanding_events == []
    end

    test "Doesn't create event cmds if no state transition happened" do
      check_details_1 = []

      check_details_2 = [
        %CheckDetail{
          check_id: "check_id_1",
          instance: "instance1",
          state: :up,
          last_checked: ~N[2020-03-11 23:00:07]
        }
      ]

      outstanding_events = []

      {new_outstanding_events, cmds} =
        RealTimeAnalytics.MonitorEvents.process_events(
          check_details_1,
          check_details_2,
          outstanding_events,
          Keyword.merge(@common_opts, new_snapshot_state: :up)
        )

      assert new_outstanding_events == outstanding_events
      assert cmds == []
    end
  end

  test "Orphaned events are cleared" do
    check_details_1 = [%CheckDetail{
      check_id: "check_id_1",
      instance: "instance1",
      state: :up,
      last_checked: ~N[2020-03-11 23:00:07]
    }]

    check_details_2 = [
      %CheckDetail{
        check_id: "check_id_1",
        instance: "instance1",
        state: :up,
        last_checked: ~N[2020-03-11 23:00:07]
      }
    ]

    outstanding_events = [
      {"event_id_1", "check_id_1", "instance1", "corr_id_1", :up}
    ]

    {new_outstanding_events, cmds} =
      RealTimeAnalytics.MonitorEvents.process_events(
        check_details_1,
        check_details_2,
        outstanding_events,
        Keyword.merge(@common_opts, new_snapshot_state: :up)
      )

    assert new_outstanding_events == []
    assert match?(
               [
                %EndEvent{monitor_event_id: "event_id_1"},
                %AddEvent{check_logical_name: "check_id_1", state: "up", end_time: end_time}
               ] when not is_nil(end_time),
               cmds
             )
  end

  test "new_oustanding_events using 5 element tuple" do
    check_details_1 = [
      %CheckDetail{check_id: "check_id_1", instance: "instance1", state: :up}
    ]

    check_details_2 = [
      %CheckDetail{
        check_id: "check_id_1",
        instance: "instance1",
        state: :down,
        last_checked: ~N[2020-03-11 23:00:07]
      }
    ]

    {new_outstanding_events, _cmds} =
      RealTimeAnalytics.MonitorEvents.process_events(
        check_details_1,
        check_details_2,
        [],
        Keyword.merge(@common_opts, new_snapshot_state: :down, correlation_id: "test-correlation-id")
      )

    assert length(new_outstanding_events) == 1
    assert {_event, _check_, _instance, correlation_id, :down} = List.first(new_outstanding_events)
    assert correlation_id == "test-correlation-id"
  end
end
