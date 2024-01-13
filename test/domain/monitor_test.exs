defmodule Domain.MonitorTest do
  use ExUnit.Case, async: true

  alias Domain.Monitor.Events.AnalyzerConfigUpdated
  alias Domain.Monitor.Events.InstanceAdded
  alias Domain.Monitor.Events.AnalyzerConfigAdded
  alias Domain.Monitor
  alias Domain.Monitor.{Commands, Events}

  test "only can set configs on known ids" do
    mon = %Monitor{
      account_id: "42",
      logical_name: "test",
      configs: [
        %{id: "known id"}
      ]
    }

    cmd = %Commands.SetExtraConfig{
      id: "123",
      config_id: "unknown id",
      key: "bar",
      value: "baz"
    }

    assert_raise ArgumentError, fn ->
      Monitor.execute(mon, cmd)
    end

    cmd = %Commands.SetExtraConfig{cmd | config_id: "known id"}

    evt = Monitor.execute(mon, cmd)

    # While we're at it, assert it's ecnrypted.
    assert String.starts_with?(evt.value, "@enc@")
  end

  test "configs can be added only once" do
    mon = %Monitor{
      account_id: "42",
      logical_name: "test",
      configs: []
    }

    cmd = %Commands.AddConfig{
      id: "123",
      config_id: "007",
      monitor_logical_name: "foo",
      interval_secs: 123,
      extra_config: %{},
      run_groups: ["TestGroup"]
    }

    multi = Monitor.execute(mon, cmd)
    refute Enum.empty?(multi.executions)

    mon = Enum.reduce(multi.executions, multi.aggregate, fn curr, acc ->
      case curr.(acc) do
        nil -> acc
        event -> Monitor.apply(acc, event)
      end
    end)

    # Second time nothing happens.
    multi = Monitor.execute(mon, cmd)

    {_agg, events} = Enum.reduce(multi.executions, {multi.aggregate, []}, fn curr, {agg, events} ->
      case curr.(agg) do
        nil -> {agg, events}
        event -> {Monitor.apply(agg, event), [event | events]}
      end
    end)

    assert Enum.empty?(events)
  end

  test "only can set steps on known configs" do
    # As long as rungroups, setups, runspec, .. all share the same code this stands for all of them.
    mon = %Monitor{
      account_id: "42",
      logical_name: "test",
      configs: [%{id: "known id"}]
    }

    cmd = %Commands.SetRunGroups{
      id: "123",
      config_id: "unknown id",
      run_groups: ["Here", "There"]
    }

    assert_raise ArgumentError, fn ->
      Monitor.execute(mon, cmd)
    end

    cmd = %Commands.SetRunGroups{cmd | config_id: "known id"}
    evt = Monitor.execute(mon, cmd)

    assert evt.__struct__ == Events.RunGroupsSet
  end

  test "Wants a create first" do
    # MET-811. There was a small window where commands from Mix tasks were sent
    # in parallel and order got mixed up. This resulted in us discovering that
    # the aggregate is fine with accepting commands before having seen a "create".

    mon = %Monitor{}
    cmd = %Commands.UpdateLastReportTime{
      id: "42_test",
      last_report: NaiveDateTime.utc_now()
    }

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, :no_create_command_seen} == Monitor.execute(mon, cmd)
    end)

    mon = %Monitor{account_id: "42", logical_name: "test"}
    assert %Events.LastReportTimeUpdated{
      id: "42_test",
      account_id: "42",
      monitor_logical_name: "test",
      last_report: cmd.last_report
    } == Monitor.execute(mon, cmd)
  end

  test "Reset command should issue events to cleanup projections" do
    mon = %Monitor{
      account_id: "test123",
      analyzer_config: %Monitor.AnalyzerConfig{},
      configs: [%Monitor.Config{id: "config1"}, %Domain.Monitor.Config{id: "config2"}],
      instances: %{ "instance1" => %Monitor.Instance{} },
      checks: %{ "check1" => %Monitor.Check{logical_name: "check1"}, "check2" => %Domain.Monitor.Check{logical_name: "check2"} },
      tags: ["tag1", "tag2"]
    }
    cmd = %Commands.Reset{
      id: "account_logicalname"
    }

    {_monitor, events} =
      Monitor.execute(mon, cmd)
      |> Commanded.Aggregate.Multi.run()

    assert length(Enum.filter(events, fn
      %Events.AnalyzerConfigRemoved{} -> true
      _ -> false end)) == 1
    assert length(Enum.filter(events, fn
      %Events.InstanceRemoved{} -> true
      _ -> false end)) == 1
    assert length(Enum.filter(events, fn
      %Events.ConfigRemoved{} -> true
      _ -> false end)) == 2
    assert length(Enum.filter(events, fn
      %Events.CheckRemoved{} -> true
      _ -> false end)) == 2
    assert length(Enum.filter(events, fn
      %Events.TagRemoved{} -> true
      _ -> false end)) == 2
    assert length(Enum.filter(events, fn
      %Events.Reset{} -> true
      _ -> false end)) == 1
  end

  test "Add tag is idempotent" do
    mon = %Monitor{
      account_id: "456",
      logical_name: "test",
      tags: []
    }
    add_1 = %Commands.AddTag{id: "456_test", tag: "foo"}
    event = Monitor.execute(mon, add_1)
    assert %Events.TagAdded{
             id: "456_test",
             account_id: "456",
             monitor_logical_name: "test",
             tag: "foo"} = event
    mon = Monitor.apply(mon, event)

    event = Monitor.execute(mon, add_1)
    assert is_nil(event)

    add_2 = %Commands.AddTag{id: "456_test", tag: "bar"}
    event = Monitor.execute(mon, add_2)
    assert not is_nil(event)
  end

  test "Remove tag is idempotent" do
    mon = %Monitor{
      account_id: "456",
      logical_name: "test",
      tags: ["foo"]
    }
    remove_1 = %Commands.RemoveTag{id: "456_test", tag: "foo"}
    event = Monitor.execute(mon, remove_1)
    assert %Events.TagRemoved{
             id: "456_test",
             account_id: "456",
             monitor_logical_name: "test",
             tag: "foo"} = event
    mon = Monitor.apply(mon, event)

    event = Monitor.execute(mon, remove_1)
    assert is_nil(event)
  end

  test "Change tag only changes existing tags" do
    mon = %Monitor{
      account_id: "456",
      logical_name: "test",
      tags: ["foo"]
    }
    chg_1 = %Commands.ChangeTag{id: "456_test", from_tag: "foo", to_tag: "bar"}
    event = Monitor.execute(mon, chg_1)
    assert %Events.TagChanged{
             id: "456_test",
             account_id: "456",
             monitor_logical_name: "test",
             from_tag: "foo",
             to_tag: "bar"} = event
    mon = Monitor.apply(mon, event)

    event = Monitor.execute(mon, chg_1)
    assert is_nil(event)
  end

  test "Metadata that looks like known tags is added when telemetry is received" do
    mon = %Monitor{
      account_id: "456",
      logical_name: "test",
      tags: ["foo"]
    }
    telem = %Commands.AddTelemetry{
      id: "456_test",
      instance_name: "test",
      check_logical_name: "check",
      value: 42.0,
      is_private: false,
      report_time: NaiveDateTime.utc_now(),
      metadata: %{
        "metrist.source" => "monitor",
        "not-a-known-tag" => "ignored"
      }
    }
    {_mon, events} =
      mon
      |> Monitor.execute(telem)
      |> Commanded.Aggregate.Multi.run()

    tag_added = Enum.filter(events, fn event -> with %type{} = event do
                                                  type == Events.TagAdded
                                                end
    end)
    refute tag_added == []
    assert ^tag_added = [%Events.TagAdded{
      tag: "metrist.source:monitor",
      monitor_logical_name: "test",
      account_id: "456",
      id: "456_test"
    }]

    # And, of course, it should be idempotent.
    mon = Map.put(mon, :tags, ["metrist.source:monitor", "something:else"])
    {_mon, events} =
      mon
      |> Monitor.execute(telem)
      |> Commanded.Aggregate.Multi.run()

    tag_added = Enum.filter(events, fn event -> with %type{} = event do
                                                  type == Events.TagAdded
                                                end
    end)
    assert tag_added == []
  end

  describe "Monitor creation" do

    test "Monitor is created on the fly from telemetry when sufficient information is available" do
      mon = %Monitor{}
      telem = %Commands.AddTelemetry{
        id: "456_test",
        instance_name: "test",
        check_logical_name: "check",
        monitor_logical_name: "logical_name",
        account_id: "account_id",
        value: 42.0,
        is_private: false,
        report_time: NaiveDateTime.utc_now(),
      }
      {mon, events} =
        mon
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert %Monitor{
        account_id: "account_id",
        logical_name: "logical_name"
      } = mon

      assert [
        %Events.Created{},
        %Events.CheckAdded{},
        %Events.InstanceAdded{},
        %Events.AnalyzerConfigAdded{},
        %Events.TelemetryAdded{},
        %Events.InstanceUpdated{},
        %Events.InstanceCheckUpdated{}
      ] = events
    end

    test "Monitor is created on the fly from error when sufficient information is available" do
      mon = %Monitor{}
      telem = %Commands.AddError{
        id: "456_test",
        instance_name: "test",
        check_logical_name: "check",
        monitor_logical_name: "logical_name",
        account_id: "account_id",
        error_id: "error_id",
        message: "message",
        is_private: false,
        report_time: NaiveDateTime.utc_now()
      }
      {mon, events} =
        mon
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert %Monitor{
        account_id: "account_id",
        logical_name: "logical_name"
      } = mon

      assert [
        %Events.Created{},
        %Events.CheckAdded{},
        %Events.InstanceAdded{},
        %Events.AnalyzerConfigAdded{},
        %Events.ErrorAdded{},
        %Events.InstanceUpdated{},
        %Events.InstanceCheckUpdated{}
      ] = events
    end

    test "Monitor is not created if creation info is missing on AddTelemetry" do
      mon = %Monitor{}
      telem = %Commands.AddTelemetry{
        id: "456_test",
        instance_name: "test",
        check_logical_name: "check",
        value: 42.0,
        is_private: false,
        report_time: NaiveDateTime.utc_now(),
      }
      assert_raise ArgumentError, fn ->
        mon
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()
      end
      assert_raise ArgumentError, "Monitor logical name was nil on new monitor, cannot create.", fn ->
        mon
        |> Monitor.execute(%Commands.AddTelemetry{telem | account_id: "account_id"})
        |> Commanded.Aggregate.Multi.run()
      end
      assert_raise ArgumentError, "Account id was nil on new monitor, cannot create.", fn ->
        mon
        |> Monitor.execute(%Commands.AddTelemetry{telem | monitor_logical_name: "monitor_logical_name"})
        |> Commanded.Aggregate.Multi.run()
      end
    end

    test "Monitor is not created if creation info is missing on AddError" do
      mon = %Monitor{}
      error = %Commands.AddError{
        id: "456_test",
        instance_name: "test",
        check_logical_name: "check",
        error_id: "error_id",
        message: "message",
        is_private: false,
        report_time: NaiveDateTime.utc_now()
      }
      assert_raise ArgumentError, fn ->
        mon
        |> Monitor.execute(error)
        |> Commanded.Aggregate.Multi.run()
      end
      assert_raise ArgumentError, "Monitor logical name was nil on new monitor, cannot create.", fn ->
        mon
        |> Monitor.execute(%Commands.AddError{error | account_id: "account_id"})
        |> Commanded.Aggregate.Multi.run()
      end
      assert_raise ArgumentError, "Account id was nil on new monitor, cannot create.", fn ->
        mon
        |> Monitor.execute(%Commands.AddError{error | monitor_logical_name: "monitor_logical_name"})
        |> Commanded.Aggregate.Multi.run()
      end
    end
  end

  describe "Telemetry/Error account_id and monitor_logical_name handling" do
    setup do
      error = %Commands.AddError{
        id: "456_test",
        instance_name: "test",
        check_logical_name: "check",
        error_id: "error_id",
        message: "message",
        is_private: false,
        report_time: NaiveDateTime.utc_now()
      }

      telem = %Commands.AddTelemetry{
        id: "456_test",
        instance_name: "test",
        check_logical_name: "check",
        value: 42.0,
        is_private: false,
        report_time: NaiveDateTime.utc_now(),
      }

      mon = %Monitor{
        account_id: "account_id",
        logical_name: "logical_name"
      }

      %{error: error, telem: telem, monitor: mon}
    end

    test "AddError on existing monitor will emit events with proper account_id & monitor_logical_name even when not on command", %{
      error: error,
      monitor: mon
    } do
      {_mon, events} =
        mon
        |> Monitor.execute(error)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.all?(events, &(&1.account_id == "account_id" && &1.monitor_logical_name == "logical_name"))
    end

    test "AddTelemetry on existing monitor will emit events with proper account_id & monitor_logical_name even when not on command", %{
      telem: telem,
      monitor: mon
    } do
      {_mon, events} =
        mon
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.all?(events, &(&1.account_id == "account_id" && &1.monitor_logical_name == "logical_name"))
    end

    test "AddTelemetry to a monitor with no analyer_config, emits an InstanceAdded and AnalyzerConfigAdded event when new instance is found", %{
      telem: telem,
      monitor: monitor
    } do
      {_mon, events} =
        monitor
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.count(events,
        fn %InstanceAdded{} -> true
        _ -> false end
      ) == 1

      assert Enum.count(events,
        fn %AnalyzerConfigAdded{} -> true
        _ -> false end
      ) == 1
    end

  test "AddTelemetry to a monitor with a non empty analyer_config.instances, emits an InstanceAdded and AnalyzerConfigUpdated event when new instance is found", %{
      telem: telem,
      monitor: monitor
    } do
      monitor = %{monitor | analyzer_config: %Domain.Monitor.AnalyzerConfig{instances: ["instance1"]}}
      {_mon, events} =
        monitor
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.count(events,
        fn %InstanceAdded{} -> true
        _ -> false end
      ) == 1

      assert Enum.count(events,
        fn %AnalyzerConfigUpdated{} -> true
        _ -> false end
      ) == 1
    end

    test "AddTelemetry to a monitor with an empty analyer_config.instances, only emits an InstanceAdded when a new instance is found", %{
      telem: telem,
      monitor: monitor
    } do
      monitor = %{monitor | analyzer_config: %Domain.Monitor.AnalyzerConfig{instances: []}}
      {_mon, events} =
        monitor
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.count(events,
        fn %InstanceAdded{} -> true
        _ -> false end
      ) == 1

      refute Enum.any?(events,
        fn %AnalyzerConfigUpdated{} -> true
        _ -> false end
      )
    end

    test "AddError Aggregate logical_name and account_id will always win if created has already fired", %{
      error: error,
      monitor: mon
    } do
      error =
        error
        |> Map.put(:account_id, "bad_account_id")
        |> Map.put(:monitor_logical_name, "bad_monitor_logical_name")

      {_mon, events} =
        mon
        |> Monitor.execute(error)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.all?(events, &(&1.account_id == "account_id" && &1.monitor_logical_name == "logical_name"))
    end

    test "AddTelemetry Aggregate logical_name and account_id will always win if created has already fired", %{
      telem: telem,
      monitor: mon
    } do
      telem =
        telem
        |> Map.put(:account_id, "bad_account_id")
        |> Map.put(:monitor_logical_name, "bad_monitor_logical_name")

      {_mon, events} =
        mon
        |> Monitor.execute(telem)
        |> Commanded.Aggregate.Multi.run()

      assert Enum.all?(events, &(&1.account_id == "account_id" && &1.monitor_logical_name == "logical_name"))
    end
  end
end
