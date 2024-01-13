defmodule Mix.Tasks.Metrist.HelpersTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Metrist.Helpers

  test "Basic command line parsing" do
    meta = [
      :account_id,
      :env,
      :dry_run,
      {:user, :u, :string, nil, "User id"}
    ]
    args = ["--env", "environment", "--dry-run", "--user", "some_user"]
    parsed = Helpers.parse_args(meta, args)

    assert parsed.account_id == "SHARED"
    assert parsed.env == "environment"
    assert parsed.dry_run
    assert parsed.user == "some_user"
  end

  test "Throws if a required option is missing" do
    meta = [
      {:user, :u, :string, :mandatory, "User id"}
    ]
    args = ["-u", "user_id"]
    assert Helpers.parse_args(meta, args).user == "user_id"
    args = []
    assert_raise RuntimeError, fn -> Helpers.parse_args(meta, args) end
  end

  test "`:keep` works" do
    # Note: currently only for strings.
    meta = [
      {:foo, :f, :keep, :mandatory, ""}
    ]
    args = ["-f", "a", "-f", "b"]
    assert Helpers.parse_args(meta, args).foo == ["a", "b"]
  end

  test "Constructs monitor_id when both account and monitor keys are given" do
    meta = [:account_id, :monitor_logical_name]
    args = ["-a", "ACCOUNT", "-m", "monitor"]
    opts = Helpers.parse_args(meta, args)
    assert opts.monitor_id == Backend.Projections.construct_monitor_root_aggregate_id("ACCOUNT", "monitor")
  end

  test "Doc generation" do
    meta = [
      :account_id,
      {:one_arg, nil, :string, :mandatory, "One arg"}
    ]

    docs = Helpers.gen_command_line_docs(meta)
    assert docs == """
    ## Options:

    * `--account-id/-a <account_id>` - The account id (default "SHARED")
    * `--one-arg <one_arg>` - One arg (required)
    """
  end

  test "command_to_map converts commands with nested objects" do
    cmd = %Domain.Monitor.Commands.SetSteps{
      id: "id",
      config_id: "config_id",
      steps: [
        %Domain.Monitor.Commands.Step{check_logical_name: "check1", timeout_secs: 123},
        %Domain.Monitor.Commands.Step{check_logical_name: "check2", timeout_secs: 123}
      ]
    }

    assert %{
      "__struct__" => "Domain.Monitor.Commands.SetSteps",
      id: "id",
      config_id: "config_id",
      steps: [
        %{"__struct__" => "Domain.Monitor.Commands.Step", check_logical_name: "check1", timeout_secs: 123},
        %{"__struct__" => "Domain.Monitor.Commands.Step", check_logical_name: "check2", timeout_secs: 123}
      ]
    } == Helpers.command_to_map(cmd)
  end

  test "command_to_struct does not convert non-command structs" do
    t = NaiveDateTime.utc_now()
    assert t == Helpers.command_to_map(t)

    event = %Domain.Account.Events.Created{
      id: "id",
      name: "name",
      free_trial_end_time: t
    }

    assert event == Helpers.command_to_map(event)
  end
end
