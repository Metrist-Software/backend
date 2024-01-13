defmodule Backend.CommandTranslatorTest do
  use ExUnit.Case, async: true

  test "Translate command received as JSON object" do
    cmd = %{
      "__struct__" => "Domain.User.Commands.Create",
      "id" => "User-5678",
      "email" => "test@example.com",
      "user_account_id" => "Account-98766",
      "uid" => "auth0:something:something",
      "is_read_only" => false
    }

    expected_cmd = %Domain.User.Commands.Create{
      id: "User-5678",
      user_account_id: "Account-98766",
      email: "test@example.com",
      uid: "auth0:something:something"
    }

    assert expected_cmd == Backend.CommandTranslator.translate(cmd)
  end

  test "Translates nested objects" do
    cmd = %Domain.Monitor.Commands.SetSteps{
      id: "id",
      config_id: "config_id",
      steps: [
        %Domain.Monitor.Commands.Step{check_logical_name: "check1", timeout_secs: 123},
        %Domain.Monitor.Commands.Step{check_logical_name: "check2", timeout_secs: 123}
      ]
    }

    translated = cmd
    |> Mix.Tasks.Metrist.Helpers.command_to_map()
    |> Jason.encode!()
    |> Jason.decode!()
    |> Backend.CommandTranslator.translate()

    assert cmd == translated
  end
end
