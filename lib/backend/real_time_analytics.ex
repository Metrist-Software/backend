defmodule Backend.RealTimeAnalytics do
  @moduledoc """
  Interface to RTA for non-RTA modules. This is considered the "public API" for
  real-time analytics.
  """

  defdelegate get_snapshot(account_id, monitor_logical_name),
    to: Backend.RealTimeAnalytics.Analysis

  def get_snapshot_or_nil(account_id, monitor_logical_name) do
    case get_snapshot(account_id, monitor_logical_name) do
      {:ok, snapshot} -> snapshot
      _ -> nil
    end
  end
end
