defmodule Test.Support.Slack.Helpers do
  alias Backend.Projections.Dbpa.{Subscription, Monitor, Snapshot}

  use TypedStruct
  require Logger

  ##### Monitors #####

  def new_monitor(name) do
    %Monitor{
      name: name,
      last_analysis_run_at: "test",
      last_analysis_run_by: "test"
    }
  end

  def new_monitor(logical_name, name) do
    %Monitor{
      logical_name: logical_name,
      name: name,
      last_analysis_run_at: "test",
      last_analysis_run_by: "test"
    }
  end

  ##### Snapshots #####

  def new_snapshot(state) do
    %Snapshot.Snapshot{
      id: "test",
      state: state,
      message: "test",
      monitor_id: "test",
      last_checked: NaiveDateTime.utc_now(),
      last_updated: NaiveDateTime.utc_now(),
      check_details: [],
      correlation_id: "test"
    }
  end

  def new_snapshot_list(0) do
    []
  end

  def new_snapshot_list(n) do
    [ { new_monitor("Monitor#{n}"),
        new_snapshot(:up)
      } ]
      ++ new_snapshot_list( n - 1 )
  end

  ##### Subscriptions #####

  def new_subscription(name) do
    %Subscription{
      delivery_method: "test",
      identity: "test",
      display_name: name,
      regions: nil,
      extra_config: %{}
    }
  end

  def new_subscription_list(0) do
    []
  end

  def new_subscription_list(n) do
    [ { new_subscription("#channel$#{n}"),
        new_monitor("Monitor#{n}")
      } ]
      ++ new_subscription_list( n - 1 )
  end

end
