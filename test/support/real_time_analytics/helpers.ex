defmodule Test.Support.RealTimeAnalytics.Helpers do
  def monitor() do
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

  def telemetry(offset, value \\ 100) do
    {base_datetime() |> NaiveDateTime.add(offset), value}
  end

  def error_from_mci(_, offset, opts \\ []) do
    error = %{error_id: "Error message", blocked_steps: opts[:blocked_steps]}
    {base_datetime() |> NaiveDateTime.add(offset), error}
  end
  def error(offset) do
    error_from_mci({"account_id", "monitor_id", "check_id", "instance_id"}, offset)
  end

  def analyzer_config(check_ids \\ ["check_id"], instance_ids \\ ["instance_id"]) do
    %Backend.Projections.Dbpa.AnalyzerConfig{
      instances: instance_ids,
      check_configs: Enum.map(check_ids, & check_config(&1))
    }
    |> Backend.Projections.Dbpa.AnalyzerConfig.fill_empty_with_defaults()
  end

  def check_config(), do: check_config("check_id")
  def check_config(check_id) do
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

  def mcis() do
    mci_1 = {"account_id","monitor_id", "check_id_1", "instance_id_1"}
    mci_2 = {"account_id","monitor_id", "check_id_1", "instance_id_2"}
    mci_3 = {"account_id","monitor_id", "check_id_2", "instance_id_1"}
    mci_4 = {"account_id","monitor_id", "check_id_2", "instance_id_2"}

    {mci_1, mci_2, mci_3, mci_4}
  end

  def base_datetime(), do: NaiveDateTime.utc_now()

  def check_detail(check_id \\ "check_id", instance_id \\ "instance_id", last_check_offset \\ 0) do
    %Backend.Projections.Dbpa.Snapshot.CheckDetail { check_id: check_id, instance: instance_id, last_checked: base_datetime() |> NaiveDateTime.add(last_check_offset) }
  end
end
