defmodule Domain.AlertManagerTest do
  use ExUnit.Case, async: true

  alias Domain.Account.AlertManager
  alias Domain.Account.Events.AlertAdded
  alias Domain.Account.Commands.{DispatchAlert, DropAlert}

  @clock_name Backend.MinuteClock.name()

  @test_alert %AlertAdded {
    id: "test_account_id",
    alert_id: "alert_id1",
    correlation_id: "correlation_id",
    monitor_logical_name: "testsignal",
    state: :degraded,
    is_instance_specific: false,
    subscription_id: nil,
    formatted_messages: %{},
    affected_regions: [],
    affected_checks: [],
    generated_at: NaiveDateTime.utc_now(),
    monitor_name: "Test Signal"
  }

  @test_filled_state %AlertManager{ monitor_alerts: %{
    "testsignal" => %{ alert: Map.put(@test_alert, :alert_id, "alert_id2") , timeout: 40 },
    "testsignal2" => %{ alert: Map.put(@test_alert, :alert_id, "alert_id3"), timeout: 500 },
    "testsignal3" => %{ alert: Map.put(@test_alert, :alert_id, "alert_id4"), timeout: 45 }
    }
  }

  describe "handle/2 AlertAdded" do
    setup do
      alert = @test_alert
      start_state = @test_filled_state
      blank_state = %AlertManager{ monitor_alerts: %{} }

      %{alert: alert, start_state: start_state, blank_state: blank_state }
    end

    test "will not send a non instance specific alert immediately", %{
      alert: alert,
      blank_state: state
    } do

      result = AlertManager.handle(state, alert)
      assert is_nil(result)
    end

    test "will send an instance specific alert immediately", %{
      alert: alert,
      start_state: state
    } do

      result = AlertManager.handle(state, Map.put(alert, :is_instance_specific, true))
      assert %DispatchAlert{} = result
    end

    # Old, still queued alert will be dropped as the new alert will contain all the old information + any new information
    test "will issue a drop if it is replacing an alert with the same state", %{
      alert: alert,
      start_state: state
    } do

      result = AlertManager.handle(state, alert)
      assert %DropAlert{ alert_id: "alert_id2", reason: :batching_replaced } = result
    end

    test "will immediatetly send the previously queued alert if the state changes", %{
      alert: alert,
      start_state: state
    } do

      alert = %AlertAdded{ alert | state: :up }
      result = AlertManager.handle(state, alert)
      %DispatchAlert{ alert: alert } = result
      assert alert.alert_id == "alert_id2"
    end
  end

  describe "handle/2 Clock.Ticked" do
    setup do
      alert = @test_alert
      start_state = @test_filled_state

      %{alert: alert, start_state: start_state}
    end

    test "will dispatch anything that are due", %{
      start_state: state
    } do

      result = AlertManager.handle(state, %Domain.Clock.Ticked{id: @clock_name, value: 45})
      assert length(result) == 2
      assert %DispatchAlert{} = Enum.at(result, 0)
      assert %DispatchAlert{} = Enum.at(result, 1)
    end

    test "will drop alerts that are too old rather than dispatching", %{
      alert: alert
    } do
      alert = %AlertAdded{ alert | generated_at: NaiveDateTime.add(NaiveDateTime.utc_now(), -600, :second) }
      state = %AlertManager{ monitor_alerts: %{ "testsignal" => %{ alert: alert, timeout: 40 } }}
      result = AlertManager.handle(state, %Domain.Clock.Ticked{id: @clock_name, value: 45})

      assert length(result) == 1
      assert %DropAlert{ reason: :too_old } = List.first(result)
    end
  end

  describe "apply/2 AlertAdded" do
    setup do
      alert = @test_alert
      start_state = @test_filled_state
      blank_state = %AlertManager{ monitor_alerts: %{} }

      %{alert: alert, start_state: start_state, blank_state: blank_state }
    end

    test "will add alert to tracked alerts", %{
      blank_state: state,
      alert: alert
    } do

      result = AlertManager.apply(state, alert)
      assert length(Map.values(result.monitor_alerts)) == 1
    end

    test "will add alert with new timeout value if existing alert has a different state", %{
      alert: alert,
      start_state: state
    } do
      alert = %AlertAdded{ alert | state: :down }
      result = AlertManager.apply(state, alert)

      %{timeout: timeout} = Map.get(result.monitor_alerts, "testsignal")
      assert timeout != 40
    end

    test "will add alert with existing timeout value if existing alert has a the same state", %{
      alert: alert,
      start_state: state
    } do
      result = AlertManager.apply(state, alert)

      %{timeout: timeout} = Map.get(result.monitor_alerts, "testsignal")
      assert timeout == 40
    end
  end

  describe "apply/2 Clock.Ticked" do
    setup do
      alert = @test_alert
      start_state = @test_filled_state

      %{alert: alert, start_state: start_state}
    end

    test "will remove stale alerts", %{
      start_state: state
    } do
      result = AlertManager.apply(state, %Domain.Clock.Ticked{id: @clock_name, value: 45})
      assert length(Map.values(result.monitor_alerts)) == 1
      assert %{ "testsignal2" => _value} = result.monitor_alerts
    end
  end
end
