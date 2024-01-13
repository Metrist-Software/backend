defmodule Backend.RealTimeAnalytics.SnapshottingTest do
  use ExUnit.Case, async: true

  alias Backend.Projections.Dbpa.Snapshot
  alias Backend.RealTimeAnalytics.Snapshotting
  alias Test.Support.RealTimeAnalytics.Helpers
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail

  describe "Snapshotting.build_full_snapshot" do
    test "All good telemetry, no errors should have :up snapshot" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        Helpers.analyzer_config(
          ["check_id_1", "check_id_2"],
          ["instance_id_1", "instance_id_2"]
        ),
        monitor(),
        []
      )

      assert snapshot.state == :up
      assert snapshot.message == "Monitor Name is operating normally in all monitored regions across all checks."

      up_check_count = snapshot.check_details
      |> Enum.filter(& &1.state == :up)
      |> Enum.count()
      assert up_check_count == 4
    end

    test "Above average recent telemetry, no errors should have :degraded snapshot" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(1, 1000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        Helpers.analyzer_config(
          ["check_id_1", "check_id_2"],
          ["instance_id_1", "instance_id_2"]
        ),
        monitor(),
        []
      )

      assert snapshot.state == :degraded
      assert snapshot.message == "Monitor Name is in a degraded state."

      degraded_check_count = snapshot.check_details
      |> Enum.filter(& &1.state == :degraded)
      |> Enum.count()
      assert degraded_check_count == 1
    end

    test "Good telemetry with recents errors should have :down snapshot" do
      mci_1 = Helpers.mcis() |> elem(0)

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, [Helpers.error_from_mci(mci_1, 2), Helpers.error_from_mci(mci_1, 3)]},
        ],
        [],
        Helpers.analyzer_config(
          ["check_id_1", "check_id_2"],
          ["instance_id_1", "instance_id_2"]
        ),
        monitor(),
        []
      )

      assert snapshot.state == :down
      assert snapshot.message == "Monitor Name is in a down state for all checks in all regions."

      down_check_count = snapshot.check_details
      |> Enum.filter(& &1.state == :down)
      |> Enum.count()
      assert down_check_count == 1
    end

    test "Timed out telemetry should have :down snapshot" do
      mci_1 = Helpers.mcis() |> elem(0)

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 900001), Helpers.telemetry(1, 900001)], 100.0, []},
        ],
        [],
        Helpers.analyzer_config(
          ["check_id_1", "check_id_2"],
          ["instance_id_1", "instance_id_2"]
        ),
        monitor(),
        []
      )

      assert snapshot.state == :down
      assert snapshot.message == "Monitor Name is in a down state for all checks in all regions."

      down_check_count = snapshot.check_details
      |> Enum.filter(& &1.state == :down)
      |> Enum.count()
      assert down_check_count == 1
    end

    test "A single check being down should have :issues snapshot" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, [Helpers.error_from_mci(mci_1, 2),Helpers.error_from_mci(mci_1, 3)]},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        Helpers.analyzer_config(
          ["check_id_1", "check_id_2"],
          ["instance_id_1", "instance_id_2"]
        ),
        monitor(),
        []
      )

      assert snapshot.state == :issues
      assert snapshot.message == "Monitor Name is experiencing issues."

      down_check_count = snapshot.check_details
      |> Enum.filter(& &1.state == :down)
      |> Enum.count()
      assert down_check_count == 1
    end

    test "build_full_snapshot will function with empty check_configs" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config([], ["instance_id_1", "instance_id_2"]),
        monitor(),
        []
      )

      assert snapshot.state == :up
      assert snapshot.message == "Monitor Name is operating normally in all monitored regions across all checks."

      up_check_count = snapshot.check_details
      |> Enum.filter(& &1.state == :up)
      |> Enum.count()
      assert up_check_count == 4
    end

    test "errors with blocked_steps marks checks as :blocked and set the snapshot state to :down" do
      mci_1 = {"account_id", "monitor_id", "check_id_1", "instance_id_1"}
      mci_2 = {"account_id", "monitor_id", "check_id_2", "instance_id_1"}
      mci_3 = {"account_id", "monitor_id", "check_id_3", "instance_id_1"}
      mci_4 = {"account_id", "monitor_id", "check_id_4", "instance_id_1"}

      errors = [
        Helpers.error_from_mci(mci_1, 2),
        Helpers.error_from_mci(mci_1, 2, blocked_steps: ["check_id_2", "check_id_3", "check_id_4"])
      ]

      snapshot =
        Snapshotting.build_full_snapshot(
          [
            {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, errors},
            {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
            {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
            {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []}
          ],
          [],
          Helpers.analyzer_config(
            ["check_id_1", "check_id_2", "check_id_3", "check_id_4"],
            ["instance_id_1"]
          ),
          monitor(),
          []
        )

      assert [:down, :blocked, :blocked, :blocked] == Enum.map(snapshot.check_details, & &1.state)
      assert snapshot.state == :down
    end

    test "An mci with no recent data does not show up on the snapshot" do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [], 100.0, []},
          {mci_4, [], 100.0, []},
        ],
        [],
        Helpers.analyzer_config(
          ["check_id_1", "check_id_2"],
          ["instance_id_1", "instance_id_2"]
        ),
        monitor(),
        []
      )

      assert Enum.count(snapshot.check_details) == 2
      assert Enum.all?(snapshot.check_details, & &1.check_id == "check_id_1")
    end

    test "should still generate snapshot if only status page data is provided" do
      status_page_id = Domain.Id.new()
      snapshot =
        Snapshotting.build_full_snapshot(
          [],
          [{ Domain.Id.new(), %Backend.Projections.Dbpa.StatusPage.ComponentChange{
            id: Domain.Id.new(),
            status_page_id: status_page_id,
            component_name: "component 1",
            status: "degraded_performance",
            state: :degraded,
            instance: "instance",
            changed_at: NaiveDateTime.utc_now()
          }},
          { Domain.Id.new(), %Backend.Projections.Dbpa.StatusPage.ComponentChange{
            id: Domain.Id.new(),
            status_page_id: status_page_id,
            component_name: "component 2",
            status: "major_outage",
            state: :down,
            instance: "instance",
            changed_at: NaiveDateTime.utc_now()
          }},
          { Domain.Id.new(), %Backend.Projections.Dbpa.StatusPage.ComponentChange{
            id: Domain.Id.new(),
            status_page_id: status_page_id,
            component_name: "component 3",
            status: "operational",
            state: :up,
            instance: "instance",
            changed_at: NaiveDateTime.utc_now()
          }}],
          Helpers.analyzer_config(),
          monitor(),
          []
        )

        assert not is_nil(snapshot)
        assert snapshot.state == :up
        assert length(snapshot.status_page_component_check_details) == 3
    end
  end

  describe "Snapshotting.update_snapshot when previous state up" do
    setup do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      analyzer_config = Helpers.analyzer_config(
        ["check_id_1", "check_id_2"],
        ["instance_id_1", "instance_id_2"]
      )

      monitor = Helpers.monitor()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config,
        monitor,
        []
      )

      [
        snapshot: snapshot,
        mcis: {mci_1, mci_2, mci_3, mci_4},
        analyzer_config: analyzer_config,
        monitor: monitor
      ]
    end

    test "Recent above threshold telemetry should go degraded", context do
      up_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000), Helpers.telemetry(4, 1000)]

      snapshot = Snapshotting.update_snapshot(up_snapshot, mci_1, telemetry, 100.0, [], analyzer_config, monitor, [])

      assert snapshot.state == :degraded
      assert snapshot.correlation_id != up_snapshot.correlation_id
    end

    test "Recent errors in one mci should cause snapshot to report issues", context do
      up_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1)]
      errors = [Helpers.error_from_mci(mci_1, 2), Helpers.error_from_mci(mci_1, 3)]

      snapshot = Snapshotting.update_snapshot(up_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :issues
      assert snapshot.correlation_id != up_snapshot.correlation_id
    end

    test "Recent errors in all mcis should cause snapshot to report down", context do
      up_snapshot = context.snapshot
      {mci_1, mci_2, mci_3, mci_4} = context.mcis
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1)]
      errors = [Helpers.error_from_mci(mci_1, 2), Helpers.error_from_mci(mci_1, 3)]

      snapshot = up_snapshot
      |> Snapshotting.update_snapshot(mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_2, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_3, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_4, telemetry, 100.0, errors, analyzer_config, monitor, [])


      assert snapshot.state == :down
      assert snapshot.correlation_id != up_snapshot.correlation_id
    end

    test "Not enough above threshold telemetry should stay up", context do
      up_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000)]
      errors = []

      snapshot = Snapshotting.update_snapshot(up_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :up
      assert snapshot.correlation_id == up_snapshot.correlation_id
    end

    test "Recent below threshold telemetry should stay up", context do
      up_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(2, 1000), Helpers.telemetry(4)]
      errors = [Helpers.error_from_mci(mci_1, 3)]

      snapshot = Snapshotting.update_snapshot(up_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :up
      assert snapshot.correlation_id == up_snapshot.correlation_id
    end
  end

  describe "Snapshotting.update_snapshot when previous state degraded" do
    setup do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      analyzer_config = Helpers.analyzer_config(
        ["check_id_1", "check_id_2"],
        ["instance_id_1", "instance_id_2"]
      )

      monitor = Helpers.monitor()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000)], 100.0, []},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, []},
        ],
        [],
        analyzer_config,
        monitor,
        []
      )

      [
        snapshot: snapshot,
        mcis: {mci_1, mci_2, mci_3, mci_4},
        analyzer_config: analyzer_config,
        monitor: monitor
      ]
    end

    test "Recent above threshold telemetry should stay degraded", context do
      degraded_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000), Helpers.telemetry(4, 1000)]

      snapshot = Snapshotting.update_snapshot(degraded_snapshot, mci_1, telemetry, 100.0, [], analyzer_config, monitor, [])

      assert snapshot.state == :degraded
      assert snapshot.correlation_id == degraded_snapshot.correlation_id
    end

    test "Recent errors should cause snapshot to report issues", context do
      degraded_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000)]
      errors = [Helpers.error_from_mci(mci_1, 3), Helpers.error_from_mci(mci_1, 4)]

      snapshot = Snapshotting.update_snapshot(degraded_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :issues
      assert snapshot.correlation_id == degraded_snapshot.correlation_id
    end

    test "Recent below threshold telemetry should go up", context do
      degraded_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 100), Helpers.telemetry(4, 100), Helpers.telemetry(5, 100)]
      errors = []

      snapshot = Snapshotting.update_snapshot(degraded_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :up
      assert snapshot.correlation_id == degraded_snapshot.correlation_id
    end
  end

  describe "Snapshotting.update_snapshot when previous state down" do
    setup do
      {mci_1, mci_2, mci_3, mci_4} = Helpers.mcis()

      analyzer_config = Helpers.analyzer_config(
        ["check_id_1", "check_id_2"],
        ["instance_id_1", "instance_id_2"]
      )

      monitor = Helpers.monitor()

      snapshot = Snapshotting.build_full_snapshot(
        [
          {mci_1, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, [Helpers.error(2), Helpers.error(3)]},
          {mci_2, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, [Helpers.error(2), Helpers.error(3)]},
          {mci_3, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, [Helpers.error(2), Helpers.error(3)]},
          {mci_4, [Helpers.telemetry(0), Helpers.telemetry(1)], 100.0, [Helpers.error(2), Helpers.error(3)]},
        ],
        [],
        analyzer_config,
        monitor,
        []
      )

      [
        snapshot: snapshot,
        mcis: {mci_1, mci_2, mci_3, mci_4},
        analyzer_config: analyzer_config,
        monitor: monitor
      ]
    end

    test "One mci recovering should cause snapshot to report issues", context do
      down_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(4), Helpers.telemetry(5), Helpers.telemetry(6)]
      errors = [Helpers.error(2), Helpers.error(3)]

      snapshot = Snapshotting.update_snapshot(down_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :issues
      assert snapshot.correlation_id == down_snapshot.correlation_id
    end

    # TODO: Related edge case - down followed by 2 above threshold values
    #   Existing C# behaviour and this has it go up, but should it be degraded instead?
    test "Recent above threshold telemetry should cause snapshot to go degraded", context do
      down_snapshot = context.snapshot
      {mci_1, mci_2, mci_3, mci_4} = context.mcis
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(4, 1000), Helpers.telemetry(5, 1000), Helpers.telemetry(6, 1000)]
      errors = [Helpers.error(2), Helpers.error(3)]

      snapshot = down_snapshot
      |> Snapshotting.update_snapshot(mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_2, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_3, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_4, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :degraded
      assert snapshot.correlation_id == down_snapshot.correlation_id
    end

    test "Recent errors should cause snapshot to stay down", context do
      down_snapshot = context.snapshot
      mci_1 = context.mcis |> elem(0)
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(4)]
      errors = [Helpers.error(2), Helpers.error(3), Helpers.error(5)]

      snapshot = Snapshotting.update_snapshot(down_snapshot, mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :down
      assert snapshot.correlation_id == down_snapshot.correlation_id
    end

    test "Recent below threshold telemetry should cause snapshot to go up", context do
      down_snapshot = context.snapshot
      {mci_1, mci_2, mci_3, mci_4} = context.mcis
      analyzer_config = context.analyzer_config
      monitor = context.monitor

      telemetry = [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(4), Helpers.telemetry(5)]
      errors = [Helpers.error(2), Helpers.error(3)]

      snapshot = down_snapshot
      |> Snapshotting.update_snapshot(mci_1, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_2, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_3, telemetry, 100.0, errors, analyzer_config, monitor, [])
      |> Snapshotting.update_snapshot(mci_4, telemetry, 100.0, errors, analyzer_config, monitor, [])

      assert snapshot.state == :up
      assert snapshot.correlation_id == down_snapshot.correlation_id
    end
  end

  describe "Snapshotting.evaluate_check_instance When check_instance is up" do
    test "Not enough recent errors should stay up" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0)],
        100.0,
        [Helpers.error(1)],
        :up,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :up
      assert detail.message == "Check Name is responding normally from instance_id"
    end

    test "Recent above threshold telemetry should go degraded" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0, 100), Helpers.telemetry(1, 100), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000), Helpers.telemetry(4, 1000)],
        100.0,
        [],
        :up,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :degraded
      assert detail.message == "Check Name is about 900% slower than normal from instance_id and is currently degraded."
    end

    test "Recent telemetry above degraded timeout should go degraded" do
      check_config = Helpers.check_config()
      |> Map.put(:degraded_timeout, 1000)

      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0, 100), Helpers.telemetry(1, 100), Helpers.telemetry(2, 1001), Helpers.telemetry(3, 1001), Helpers.telemetry(4, 1001)],
        100.0,
        [],
        :up,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        check_config,
        Helpers.monitor()
      )

      assert detail.state == :degraded
      assert detail.message == "Check Name timed out after the warning timeout threshold of 1000 seconds."
    end

    test "Recent errors should cause check to go down" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0)],
        100.0,
        [Helpers.error(1), Helpers.error(2)],
        :up,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :down
      assert detail.message == "Check Name is not currently responding from instance_id and is currently down."
    end

    test "Recent telemetry above timeout should go down" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0, 900001),Helpers.telemetry(1, 900001)],
        100.0,
        [],
        :up,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :down
      assert detail.message == "Check Name timed out after the error timeout threshold of 900000 seconds."
    end
  end

  describe "Snapshotting.evaluate_check_instance When check_instance is degraded" do
    test "Recent below threshold telemetry should go up" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 100), Helpers.telemetry(4, 100), Helpers.telemetry(5, 100)],
        100.0,
        [],
        :degraded,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :up
      assert detail.message == "Check Name is responding normally from instance_id"
    end

    test "Recent errors should go down" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000)],
        100.0,
        [Helpers.error(3), Helpers.error(4)],
        :degraded,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :down
      assert detail.message == "Check Name is not currently responding from instance_id and is currently down."
    end

    test "Not enough below threshold telemetry should stay degraded" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 100), Helpers.telemetry(4, 100)],
        100.0,
        [],
        :degraded,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :degraded
      # See comment in Snapshotting.ex, line 146
      # assert detail.message == "Check Name is about 100% slower than normal from instance_id and is currently degraded."
    end
  end

  describe "Snapshotting.evaluate_check_instance When check_instance is down" do
    test "Recent below threshold telemetry should go up" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(2, 100), Helpers.telemetry(3, 100), Helpers.telemetry(4, 100)],
        100.0,
        [Helpers.error(0), Helpers.error(1)],
        :down,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :up
      assert detail.message == "Check Name is responding normally from instance_id"
    end

    test "Recent above threshold telemetry should go degraded" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000), Helpers.telemetry(4, 1000)],
        100.0,
        [Helpers.error(0), Helpers.error(1)],
        :down,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :degraded
      assert detail.message == "Check Name is about 900% slower than normal from instance_id and is currently degraded."
    end

    test "Not enough recent below threshold telemetry should stay down" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(2, 100)],
        100.0,
        [Helpers.error(0), Helpers.error(1)],
        :down,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :down
      assert detail.message == "Check Name is not currently responding from instance_id and is currently down."
    end

    test "Limited recent telemetry above degraded threshold should stay down" do
      # There's enough telemetry to go back to an up state, but not enough to go to degraded
      # If any of the telemetry is degraded, stay down
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000)],
        100.0,
        [Helpers.error(0), Helpers.error(1)],
        :down,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :down
    end

    test "Mixed recent telemetry should go degraded" do
      detail = Backend.RealTimeAnalytics.Snapshotting.evaluate_check_instance(
        [Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000), Helpers.telemetry(4, 100)],
        100.0,
        [Helpers.error(0), Helpers.error(1)],
        :down,
        {"account_id", "monitor_id", "check_id", "instance_id"},
        Helpers.check_config(),
        Helpers.monitor()
      )

      assert detail.state == :degraded
    end
  end

  describe "Snapshotting.has_recent_errors?/3" do
    test "Recent errors should return true" do
      result = Snapshotting.has_recent_errors?(
        [Helpers.telemetry(0)],
        [Helpers.error(1), Helpers.error(2), Helpers.error(3)],
        Helpers.check_config()
      )

      assert result == true
    end

    test "No errors should return false" do
      result = Snapshotting.has_recent_errors?(
        [Helpers.telemetry(0)],
        [],
        Helpers.check_config()
      )

      assert result == false
    end

    test "Old errors should return false" do
      result = Snapshotting.has_recent_errors?(
        [Helpers.telemetry(4)],
        [Helpers.error(1), Helpers.error(2), Helpers.error(3)],
        Helpers.check_config()
      )

      assert result == false
    end

    test "No telemetry, no errors should return false" do
      result = Snapshotting.has_recent_errors?(
        [], [], Helpers.check_config()
      )

      assert result == false
    end
  end

  describe "Snapshotting.is_check_down?/5" do
    test "Any state other than down should return false" do
      Enum.each(Snapshot.states() -- [:down], fn state ->
        assert Snapshotting.is_check_down?(
          [], 100.0, [], state, Helpers.check_config()
        ) == false

      end)
    end
    test "Down state should return true" do
      assert Snapshotting.is_check_down?(
        [], 100.0, [], :down, Helpers.check_config()
      ) == true
    end
  end

  describe "Snapshotting.is_down_and_cannot_be_up_yet?/4" do
    test "Up state should return false" do
      result = Snapshotting.is_down_and_cannot_be_up_yet?(
        [], 100.0, [], :up, Helpers.check_config()
      )

      assert result == false
    end

    test "Degraded state should return false" do
      result = Snapshotting.is_down_and_cannot_be_up_yet?(
        [], 100.0, [], :degraded, Helpers.check_config()
      )

      assert result == false
    end

    test "Not enough recent telemetry should return true" do
      result = Snapshotting.is_down_and_cannot_be_up_yet?(
        [Helpers.telemetry(1)],
        100.0,
        [Helpers.error(0)],
        :down,
        Helpers.check_config()
      )

      assert result == true
    end

    test "Enough recent telemetry should return false" do
      result = Snapshotting.is_down_and_cannot_be_up_yet?(
        [Helpers.telemetry(1), Helpers.telemetry(2)],
        100.0,
        [Helpers.error(0)],
        :down,
        Helpers.check_config()
      )

      assert result == false
    end
  end

  describe "Snapshotting.is_degraded_and_cannot_be_up_yet?/4" do
    test "Up state should return false" do
      result = Snapshotting.is_degraded_and_cannot_be_up_yet?(
        [], 150.0, :up, Helpers.check_config()
      )

      assert result == false
    end

    test "Down state should return false" do
      result = Snapshotting.is_degraded_and_cannot_be_up_yet?(
        [], 150.0, :down, Helpers.check_config()
      )

      assert result == false
    end

    test "Enough recent telemetry below threshold should return false" do
      result = Snapshotting.is_degraded_and_cannot_be_up_yet?(
        [Helpers.telemetry(0, 100), Helpers.telemetry(1, 100), Helpers.telemetry(2, 100)],
        150.0,
        :degraded,
        Helpers.check_config()
      )

      assert result == false
    end

    test "Not enough recent telemetry below threshold should return true" do
      result = Snapshotting.is_degraded_and_cannot_be_up_yet?(
        [Helpers.telemetry(0, 100), Helpers.telemetry(1, 100)],
        150.0,
        :degraded,
        Helpers.check_config()
      )

      assert result == true
    end
  end

  describe "Snapshotting.has_recent_above_threshold?/4" do
    test "No telemetry should return false" do
      result = Snapshotting.has_recent_above_threshold?(
        [],
        150.0,
        5.0,
        Helpers.check_config()
      )

      assert result == false
    end

    test "Not enough telemetry should return false" do
      result = Snapshotting.has_recent_above_threshold?(
        [Helpers.telemetry(0)],
        150.0,
        5.0,
        3
      )

      assert result == false
    end

    test "Recent telemetry below threshold should return false" do
      result = Snapshotting.has_recent_above_threshold?(
        [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(2)],
        150.0,
        5.0,
        3
      )

      assert result == false
    end

    test "Not enough recent telemetry above threshold should return false" do
      result = Snapshotting.has_recent_above_threshold?(
        [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 100), Helpers.telemetry(2, 1000), Helpers.telemetry(3, 1000)],
        150.0,
        5.0,
        3
      )

      assert result == false
    end

    test "Recent telemetry above threshold should return false" do
      result = Snapshotting.has_recent_above_threshold?(
        [Helpers.telemetry(0, 1000), Helpers.telemetry(1, 1000), Helpers.telemetry(2, 1000)],
        150.0,
        5.0,
        3
      )

      assert result == true
    end
  end

  describe "Snapshotting.is_timed_out?/4" do
    test "Not enough recent telemetry should return false" do
      result = Snapshotting.is_timed_out?([], [], 900000, 2)

      assert result == false
    end

    test "Recent telemetry below timeout should return false" do
      result = Snapshotting.is_timed_out?(
        [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(2)],
        [],
        900000,
        2
      )

      assert result == false
    end

    test "Recent telemetry above timeout should return true" do
      result = Snapshotting.is_timed_out?(
        [Helpers.telemetry(0, 900001), Helpers.telemetry(1, 900001)],
        [],
        900000,
        2
      )

      assert result == true
    end

    test "Not enough recent telemetry above timeout should return false" do
      result = Snapshotting.is_timed_out?(
        [Helpers.telemetry(1, 900001), Helpers.telemetry(2, 100), Helpers.telemetry(3, 900001)],
        [],
        900000,
        2
      )

      assert result == false
    end
  end

  describe "Snapshotting.should_include_mci/2" do
    test "MCI's will be excluded if instance not in config" do
      {mci_1, mci_2, _mci_3, _mci_4} = Helpers.mcis()

      config = Helpers.analyzer_config(
        ["check_id_1", "check_id_2"],
        ["instance_id_2"]
      )

      result = Snapshotting.should_include_mci(mci_1, config)
      result2 = Snapshotting.should_include_mci(mci_2, config)

      assert result == false
      assert result2 == true
    end

    test "MCI's will be excluded if check not in config" do
      {mci_1, _mci_2, mci_3, _mci_4} = Helpers.mcis()

      config = Helpers.analyzer_config(
        ["check_id_2"],
        ["instance_id_1", "instance_id_2"]
      )

      result = Snapshotting.should_include_mci(mci_1, config)
      result2 = Snapshotting.should_include_mci(mci_3, config)

      assert result == false
      assert result2 == true
    end

    test "MCI's will be included if check_configs is empty" do
      {mci_1, _mci_2, mci_3, _mci_4} = Helpers.mcis()

      config = Helpers.analyzer_config(
        [],
        ["instance_id_1", "instance_id_2"]
      )

      result = Snapshotting.should_include_mci(mci_1, config)
      result2 = Snapshotting.should_include_mci(mci_3, config)

      assert result == true
      assert result2 == true
    end

    test "MCI's will be included if instances is empty" do
      {mci_1, mci_2, _mci_3, _mci_4} = Helpers.mcis()

      config = Helpers.analyzer_config(
        ["check_id_1", "check_id_2"],
        []
      )

      result = Snapshotting.should_include_mci(mci_1, config)
      result2 = Snapshotting.should_include_mci(mci_2, config)

      assert result == true
      assert result2 == true
    end
  end

  describe "Snapshotting.remove_stale_check_details/1" do
    test "Removes check details that is 24 hours old" do
      last_checked = NaiveDateTime.utc_now() |> Timex.shift(hours: -24)
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{
        check_details: [
          %CheckDetail{
            last_checked: last_checked
          },
          %CheckDetail{
            last_checked: last_checked
          }
        ]
      }

      snapshot = Snapshotting.remove_stale_check_details(snapshot)
      assert length(snapshot.check_details) == 0
    end
  end

  describe "Snapshotting.order_check_details/2" do
    test "Check details will be in the run_step order then alphabetical in the snapshot if run_steps is provided" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{
        check_details: [
          %CheckDetail{
            check_id: "test_check_1"
          },
          %CheckDetail{
            check_id: "test_check_4"
          },
          %CheckDetail{
            check_id: "test_check_3"
          },
          %CheckDetail{
            check_id: "test_check_2"
          }
        ]
      }

      snapshot = Snapshotting.order_check_details(snapshot, ["test_check_2", "test_check_1"])
      assert Enum.map(snapshot.check_details, &(&1.check_id)) == ["test_check_2", "test_check_1", "test_check_3", "test_check_4"]
    end
  end

  describe "Snapshotting.get_check_config_for_mci/2" do
    test "Check config will have defaults if analyzer config has nils" do
      config = %Backend.Projections.Dbpa.AnalyzerConfig{
        instances: nil,
        check_configs: [
          %Backend.Projections.Dbpa.CheckConfig{
            check_logical_name: "1",
            degraded_threshold: nil,
            degraded_down_count: nil,
            degraded_up_count: nil,
            degraded_timeout: nil,
            error_down_count: nil,
            error_up_count: nil,
            error_timeout: nil
          }
        ]
      }

      check_config = Snapshotting.get_check_config_for_mci(config, {nil, nil, "1", nil})
      assert check_config.degraded_threshold == 5.0
      assert check_config.degraded_down_count == 3
      assert check_config.degraded_up_count == 3
      assert check_config.degraded_timeout == 900_000
      assert check_config.error_down_count == 2
      assert check_config.error_up_count == 2
      assert check_config.error_timeout == 900_000
    end

    test "Check config has defaults if analyzer config doesn't have check_config" do
      config = %Backend.Projections.Dbpa.AnalyzerConfig{
        instances: nil,
        check_configs: []
      }

      check_config = Snapshotting.get_check_config_for_mci(config, {nil, nil, "1", nil})
      assert check_config.degraded_threshold == 5.0
      assert check_config.degraded_down_count == 3
      assert check_config.degraded_up_count == 3
      assert check_config.degraded_timeout == 900_000
      assert check_config.error_down_count == 2
      assert check_config.error_up_count == 2
      assert check_config.error_timeout == 900_000
    end

    test "Check config will have provided values and not defaults if present" do
      config = %Backend.Projections.Dbpa.AnalyzerConfig{
        instances: nil,
        check_configs: [
          %Backend.Projections.Dbpa.CheckConfig{
            check_logical_name: "1",
            degraded_threshold: 6.0,
            degraded_down_count: 5,
            degraded_up_count: 5,
            degraded_timeout: 100_000,
            error_down_count: 6,
            error_up_count: 6,
            error_timeout: 100_000
          }
        ]
      }

      check_config = Snapshotting.get_check_config_for_mci(config, {nil, nil, "1", nil})
      assert check_config.degraded_threshold == 6.0
      assert check_config.degraded_down_count == 5
      assert check_config.degraded_up_count == 5
      assert check_config.degraded_timeout == 100_000
      assert check_config.error_down_count == 6
      assert check_config.error_up_count == 6
      assert check_config.error_timeout == 100_000
    end

  end

  describe "Snapshotting.remove_duplicate_check_details/1" do
    test "Duplicate check details with older last_checked will be removed" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{ check_details: [
        Helpers.check_detail("check_1", "instance_1", 1),
        Helpers.check_detail("check_1", "instance_1", 0),
        Helpers.check_detail("check_2", "instance_2", 0),
        Helpers.check_detail("check_3", "instance_1", 0),
        Helpers.check_detail("check_3", "instance_1", 1)
        ]}

       snapshot = Snapshotting.remove_duplicate_check_details(snapshot)

       assert length(snapshot.check_details) == 3
    end

    test "When there are no duplicates, the same list will be returned" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{ check_details: [
        Helpers.check_detail("check_1", "instance_1", 1),
        Helpers.check_detail("check_2", "instance_2", 0),
        Helpers.check_detail("check_3", "instance_1", 1),
      ]}

      old_check_details = snapshot.check_details

      snapshot = Snapshotting.remove_duplicate_check_details(snapshot)

      assert snapshot.check_details == old_check_details
    end
  end

  describe "Snapshotting.update_status_page_component_check_details/2" do
    test "Updates the check detail" do
      event = %{
        component_id: "check_id",
        state: "down",
        changed_at: ~N[2000-01-01 23:00:01]
      }

      result =
        Snapshotting.update_status_page_component_check_details(
          %{
            status_page_component_check_details: [
              %CheckDetail{
                check_id: "check_id",
                state: :up
              }
            ],
            last_updated: ~N[2000-01-01 23:00:00]
          },
          event
        )

      [actual_check_detail] = result.status_page_component_check_details
      assert :down == actual_check_detail.state
    end

    test "Does not update the last_updated field if no check detail is updated" do
      last_updated = ~N[2000-01-01 23:00:00]

      event = %{
        component_id: "not found",
        state: "down",
        changed_at: ~N[2000-01-01 23:00:01]
      }

      result =
        Snapshotting.update_status_page_component_check_details(
          %{
            status_page_component_check_details: [
              %CheckDetail{
                check_id: "check",
                state: :up
              }
            ],
            last_updated: last_updated
          },
          event
        )

      assert last_updated == result.last_updated
    end
  end

  describe "Snapshotting.set_snapshot_state/1" do
    test "Blocked check details will set snapshot state to issues" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{
        check_details: [
          Map.put(Helpers.check_detail("check_1", "instance_1", 1), :state, :up),
          Map.put(Helpers.check_detail("check_2", "instance_1", 1), :state, :blocked),
          Map.put(Helpers.check_detail("check_3", "instance_1", 1), :state, :blocked),
        ],
        state: :up
      }
      |> Snapshotting.set_snapshot_state()

      assert snapshot.state == :issues
    end

    test "All check details being down or blocked will set down" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{
        check_details: [
          Map.put(Helpers.check_detail("check_1", "instance_1", 1), :state, :down),
          Map.put(Helpers.check_detail("check_2", "instance_1", 1), :state, :blocked),
          Map.put(Helpers.check_detail("check_3", "instance_1", 1), :state, :blocked),
        ],
        state: :up
      }
      |> Snapshotting.set_snapshot_state()

      assert snapshot.state == :down
    end

    test "A single down will set issues" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{
        check_details: [
          Map.put(Helpers.check_detail("check_1", "instance_1", 1), :state, :up),
          Map.put(Helpers.check_detail("check_2", "instance_1", 1), :state, :down),
          Map.put(Helpers.check_detail("check_3", "instance_1", 1), :state, :blocked),
        ],
        state: :up
      }
      |> Snapshotting.set_snapshot_state()

      assert snapshot.state == :issues
    end

    test "One or more degraded will set degraded" do
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot{
        check_details: [
          Map.put(Helpers.check_detail("check_1", "instance_1", 1), :state, :up),
          Map.put(Helpers.check_detail("check_2", "instance_1", 1), :state, :degraded),
          Map.put(Helpers.check_detail("check_3", "instance_1", 1), :state, :degraded),
        ],
        state: :up
      }
      |> Snapshotting.set_snapshot_state()

      assert snapshot.state == :degraded
    end
  end

  describe "When average is nil" do
    test "has_recent_above_threshold should return false" do
      result = Snapshotting.has_recent_above_threshold?(
        [Helpers.telemetry(0), Helpers.telemetry(1), Helpers.telemetry(2)],
        nil,
        5.0,
        3
      )
      assert result == false
    end

    test "is_degraded_and_cannot_be_up_yet? should return false" do
      result = Snapshotting.is_degraded_and_cannot_be_up_yet?(
        [Helpers.telemetry(0, 100), Helpers.telemetry(1, 100), Helpers.telemetry(2, 100)],
        nil,
        :degraded,
        Helpers.check_config()
      )
      assert result == false
    end
  end

  describe "Snapshotting.set_blocked_steps/3" do
    test "Blocked checks will return a proper check_details message" do

      monitor = %Backend.Projections.Dbpa.Monitor {
      }
      snapshot = %Backend.Projections.Dbpa.Snapshot.Snapshot {
        check_details: [
          %Backend.Projections.Dbpa.Snapshot.CheckDetail{
            instance: "instance_1",
            check_id: "check_1",
            state: nil,
            message: nil
          }
        ]
      }
      |> Snapshotting.set_blocked_steps([{"instance_1", "check_1"}] |> MapSet.new(), monitor)

      check_detail = List.first(snapshot.check_details)

      assert check_detail.state == :blocked
      assert check_detail.message == "check_1 is currently blocked by a failure in a previous step in instance_1."
    end
  end

  # Helper methods

  defp monitor() do
    %Backend.Projections.Dbpa.Monitor{
      logical_name: "monitor_id",
      name: "Monitor Name",
      checks: [
        %Backend.Projections.Dbpa.MonitorCheck{
          logical_name: "check_id",
          name: "Check Name"
        },
        %Backend.Projections.Dbpa.MonitorCheck{
          logical_name: "check_id_1",
          name: "Check 1 Name"
        },
        %Backend.Projections.Dbpa.MonitorCheck{
          logical_name: "check_id_2",
          name: "Check 2 Name"
        },
      ]
    }
  end

  defp analyzer_config(check_ids, instance_ids) do
    %Backend.Projections.Dbpa.AnalyzerConfig{
      instances: instance_ids,
      check_configs: Enum.map(check_ids, & check_config(&1))
    }
    |> Backend.Projections.Dbpa.AnalyzerConfig.fill_empty_with_defaults()
  end

  defp check_config(check_id) do
    %Backend.Projections.Dbpa.CheckConfig{
      check_logical_name: check_id,
      degraded_threshold: 5.0,
      degraded_down_count: 3,
      degraded_up_count: 3,
      degraded_timeout: 900000,
      error_down_count: 2,
      error_up_count: 2,
      error_timeout: 900000
    }
  end
end
