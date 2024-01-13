defmodule Backend.Projections.Telemetry.MonitorTelemetry do
  use Ecto.Schema

  @primary_key false
  schema "monitor_telemetry" do
    field :time, :naive_datetime_usec
    field :monitor_id, :string
    field :check_id, :string
    field :instance_id, :string
    field :account_id, :string
    field :value, :float
  end

  import Ecto.Query

  def telemetry(account_id, monitor_name \\ nil, timespan \\ nil) do
    __MODULE__
    |> with_timespan(timespan)
    |> with_monitor(monitor_name)
    |> with_account(account_id)
    |> Backend.TelemetryRepo.all()
  end

  defp with_account(query, account_id) do
    query
    |> where([e], e.account_id == ^account_id)
  end

  defp with_monitor(query, nil), do: query
  defp with_monitor(query, []), do: query
  defp with_monitor(query, logical_name) do
    query
    |> where([e], e.monitor_id == ^logical_name)
  end

  defp with_timespan(query, nil), do: query
  defp with_timespan(query, timespan) do
    cutoff = Backend.Telemetry.cutoff_for_timespan(timespan)
    query
    |> where([e], e.time > ^cutoff)
   end

  def orchestrator_count(excluded_account_ids) do
    instances = __MODULE__
    |> select([t], [t.account_id, t.instance_id])
    |> where([t], t.account_id not in ^excluded_account_ids)
    |> with_timespan("week")
    |> group_by([t], [t.account_id, t.instance_id])
    |> Backend.TelemetryRepo.all()
    total = Enum.count(instances)
    accounts =
      instances
      |> Enum.map(fn [account, _instance] -> account end)
      |> Enum.uniq()
      |> Enum.count()
    %{total: total, accounts: accounts}
  end
end
