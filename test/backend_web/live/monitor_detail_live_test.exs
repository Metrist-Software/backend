defmodule BackendWeb.MonitorDetailLiveTest do
  use ExUnit.Case, async: true

  alias Backend.Projections.Dbpa.MonitorConfig
  alias(Domain.Monitor.Commands.Step)

  test "Ordering for a regular monitor" do
    checks = [%{logical_name: "step_two"}, %{logical_name: "step_one"}]

    configs = [
      %MonitorConfig{
        steps: [
          %Step{check_logical_name: "step_one", timeout_secs: 0},
          %Step{check_logical_name: "step_two", timeout_secs: 0}
        ]
      }
    ]

    sorted_checks =
      BackendWeb.MonitorDetailLive.sort_by_step_order(checks, configs)

    assert sorted_checks == [
      [%{logical_name: "step_one"}, %{logical_name: "step_two"}],
      []
    ]
  end

  test "Ordering for a monitor with multiple instances" do
    checks = [%{logical_name: "step_two"}, %{logical_name: "step_three"}, %{logical_name: "step_one"}]

    configs = [
      %MonitorConfig{
        steps: [
          %Step{check_logical_name: "step_one", timeout_secs: 0},
          %Step{check_logical_name: "step_two", timeout_secs: 0}
        ]
      },
      %MonitorConfig{
        steps: [
          %Step{check_logical_name: "step_three", timeout_secs: 0},
        ]
      }
    ]

    sorted_checks =
      BackendWeb.MonitorDetailLive.sort_by_step_order(checks, configs)

    assert sorted_checks == [
      [%{logical_name: "step_one"}, %{logical_name: "step_two"}],
      [%{logical_name: "step_three"}],
      []
    ]
  end

  test "Ordering for an in-process only monitor" do
    checks = [%{logical_name: "step_one"}]

    configs = []

    sorted_checks = BackendWeb.MonitorDetailLive.sort_by_step_order(checks, configs)

    assert sorted_checks == [
      [],
      [%{logical_name: "step_one"}]
    ]
  end

  describe "Duration formatting" do
    import BackendWeb.MonitorDetailLive, only: [format_duration: 1]

    test "Duration formatting leaves out seconds bits" do
      assert "1 hour, 2 minutes" == format_duration(Timex.Duration.from_clock({1, 2, 3, 0}))
    end

    test "Durations shorter than an hour" do
      assert "2 minutes" == format_duration(Timex.Duration.from_clock({0, 2, 3, 4}))
    end

    test "Durations longer than a day" do
      assert "1 day, 6 hours, 2 minutes" == format_duration(Timex.Duration.from_clock({30, 2, 3, 4}))
    end

    test "Durations with no seconds" do
      assert "1 day, 6 hours, 2 minutes" == format_duration(Timex.Duration.from_clock({30, 2, 0, 0}))
    end

    test "Durations under a minute" do
      assert "Just now" == format_duration(Timex.Duration.from_clock({0, 0, 15, 10}))
    end
  end
end
