defmodule Backend.RealTimeAnalytics.AlertingTest do
  use ExUnit.Case, async: true

  alias Backend.RealTimeAnalytics.Alerting
  alias Backend.RealTimeAnalytics.Snapshotting

  alias Test.Support.RealTimeAnalytics.Helpers

  describe "Alert creation" do
    test "nil previous_snapshot, current up should not alert" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()
      current_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      alerts = Alerting.create_alerts(nil, current_snapshot, Helpers.monitor(), [])

      assert alerts == []
      assert Enum.empty?(alerts)
    end

    test "nil previous_snapshot, current degraded with no outstanding event should alert" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()
      current_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 10000), Helpers.telemetry(1, 10000), Helpers.telemetry(2, 10000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      alerts = Alerting.create_alerts(nil, current_snapshot, Helpers.monitor(), [])

      assert Enum.count(alerts) == 2

      Enum.each(alerts, fn alert ->
        assert alert.state == :degraded
      end)
    end

    test "nil previous_snapshot, current degraded with outstanding degraded event should not alert" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()
      current_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 10000), Helpers.telemetry(1, 10000), Helpers.telemetry(2, 10000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      alerts = Alerting.create_alerts(nil, current_snapshot, Helpers.monitor(), [{"id", "check_id_1", "instance_id_1", "correlation_id", :degraded}])

      assert alerts == []
      assert Enum.empty?(alerts)
    end

    test "nil previous_snapshot, current degraded with outstanding down event should alert" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()
      current_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 10000), Helpers.telemetry(1, 10000), Helpers.telemetry(2, 10000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      alerts = Alerting.create_alerts(nil, current_snapshot, Helpers.monitor(), [{"id", "check_id_1", "instance_id_1", "correlation_id", :down}])

      assert Enum.count(alerts) == 2

      Enum.each(alerts, fn alert ->
        assert alert.state == :degraded
      end)
    end

    test "nil previous_snapshot, current degraded with outstanding degraded on other check should only create check level alerts" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()
      current_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 10000), Helpers.telemetry(1, 10000), Helpers.telemetry(2, 10000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      check_id = elem(mci_2, 2)
      instance_id = elem(mci_2, 3)

      alerts = Alerting.create_alerts(nil, current_snapshot, Helpers.monitor(), [{"id", check_id, instance_id, "correlation_id", :degraded}])

      assert Enum.count(alerts) == 1
      [alert] = alerts

      assert Enum.count(alert.affected_checks) == 2
      assert alert.is_instance_specific == true
    end

    test "up previous_snapshot, current degraded" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      previous_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 10000), Helpers.telemetry(1, 10000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      current_snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 10000), Helpers.telemetry(1, 10000), Helpers.telemetry(2, 10000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config(),
        Helpers.monitor(),
        []
      )

      alerts = Alerting.create_alerts(previous_snapshot, current_snapshot, Helpers.monitor(), [])

      assert Enum.count(alerts) == 2

      Enum.each(alerts, fn alert ->
        assert alert.state == :degraded
      end)
    end
  end

  defp analyzer_config(),
    do:
      Helpers.analyzer_config(
        ["check_id_1", "check_id_2"],
        ["instance_id_1", "instance_id_2"]
      )
end
