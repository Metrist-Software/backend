defmodule Backend.Projections.Dbpa.MonitorConfigTest do
  use ExUnit.Case, async: true

  alias Backend.Projections.Dbpa.MonitorConfig
  alias Domain.Monitor.Commands.RunSpec
  alias Domain.Monitor.Commands.Step

  test "atomification" do
    db_result = %MonitorConfig{
      steps: [
        %{"check_logical_name" => "Check", "timeout_secs" => 0}
      ],
      run_spec: %{
        "run_type" => "dll",
        "name" => "my_name"
      }
    }

    expected = %MonitorConfig{
      steps: [
        %Step{check_logical_name: "Check", timeout_secs: 0}
      ],
      run_spec: %RunSpec{
        run_type: :dll,
        name: "my_name"
      }
    }

    assert expected == MonitorConfig.deserialize_inner_json(db_result)
  end
end
