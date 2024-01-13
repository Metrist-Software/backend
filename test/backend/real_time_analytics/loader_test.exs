defmodule Backend.RealTimeAnalytics.LoaderTest do
  # It's cleaner to not have tests for logging run concurrently.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    level = Logger.level()
    Logger.configure(level: :warning)
    on_exit(fn -> Logger.configure(level: level) end)
  end

  describe "init_mci/3 invalid MCI checks" do
    test "init_mci will warn and not try to start mci has no account_id" do
      assert capture_log(fn ->
        Backend.RealTimeAnalytics.Loader.init_mci(nil, {nil,"monitor_id", "check_id_1", "instance_id_1"})
      end) =~ "Ignoring init_mci request for MCI "
    end

    test "init_mci will warn and not try to start mci has no monitor_id" do
      assert capture_log(fn ->
        Backend.RealTimeAnalytics.Loader.init_mci(nil, {"account_id", nil, "check_id_1", "instance_id_1"})
      end) =~ "Ignoring init_mci request for MCI "
    end

    test "init_mci will warn and not try to start mci has no check_id" do
      assert capture_log(fn ->
        Backend.RealTimeAnalytics.Loader.init_mci(nil, {"account_id","monitor_id", nil, "instance_id_1"})
      end) =~ "Ignoring init_mci request for MCI "
    end

    test "init_mci will warn and not try to start mci has no instance_id" do
      assert capture_log(fn ->
        Backend.RealTimeAnalytics.Loader.init_mci(nil, {"account_id","monitor_id", "check_id_1", nil})
      end) =~ "Ignoring init_mci request for MCI "
    end
  end
end
