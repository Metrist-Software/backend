defmodule BackendWeb.AgentControllerTest do
  use ExUnit.Case, async: true

  alias BackendWeb.AgentController.RunConfig

  test "test convert monitor config" do
    configs = [
      %Backend.Projections.Dbpa.MonitorConfig{
        monitor_logical_name: "test_do_not_use",
        interval_secs: 23,
        extra_config: %{"item1" => "value1"},
        run_spec: %{run_type: :dll, name: "test"},
        steps: [
          %{check_logical_name: "StepOne", timeout_secs: 90.0},
          %{check_logical_name: "StepTwo", timeout_secs: 2.5}
        ]
      }
    ]

    instances = [
      %Backend.Projections.Dbpa.MonitorInstance{
        monitor_logical_name: "test_do_not_use",
        last_report: ~N[2013-12-11 10:09:08],
        check_last_reports: %{
          "StepOne" => ~N[2012-11-10 09:08:07]
        }
      }
    ]

    expected =
      %RunConfig{
        monitors: [
          %RunConfig.Monitor{
            monitor_logical_name: "test_do_not_use",
            interval_secs: 23,
            run_spec: %{run_type: :dll, name: "test"},
            extra_config: %{"item1" => "value1"},
            # The last run time of the whole monitor because the config did not specify a step
            last_run_time: ~N[2013-12-11 10:09:08],
            steps: [
              %{
                check_logical_name: "StepOne",
                timeout_secs: 90.0
              },
              %{
                check_logical_name: "StepTwo",
                timeout_secs: 2.5
              }
            ]
          }
        ]
      }


    assert expected == BackendWeb.AgentController.build_run_config(configs, instances)
  end

  test "translate_instance translates aws:region to region" do
    assert BackendWeb.AgentController.translate_instance("aws:us-west-1") == "us-west-1"
    assert BackendWeb.AgentController.translate_instance("us-west-1") == "us-west-1"
    assert BackendWeb.AgentController.translate_instance("gcp:us-west1") == "gcp:us-west1"
  end

end
