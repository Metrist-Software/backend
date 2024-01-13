defmodule BackendWeb.SnapshotController do
  use BackendWeb, :controller

  action_fallback BackendWeb.FallbackController

  require Logger

  def get(conn, %{"AccountId" => account_id, "Name" => monitor_logical_name}) do
    with {:ok, snapshot} <- Backend.RealTimeAnalytics.get_snapshot(account_id, monitor_logical_name) do
      json(conn, snapshot)
    end
  end

  def list(conn, %{"account" => account_id}) do
    snapshots = Backend.Projections.list_monitors(account_id)
    |> Enum.map(& Backend.RealTimeAnalytics.get_snapshot_or_nil(account_id, &1.logical_name))
    |> Enum.reject(&is_nil/1)

    json(conn, snapshots)
  end
end
