defmodule Backend.Projections.Aggregate.ApiUseAggregate do
  use Ecto.Schema

  @primary_key false
  schema "aggregate_api_use" do
    field :id, :string
    field :time, :naive_datetime_usec
    field :account_id, :string
    field :is_internal, :boolean
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Aggregate.Common

  def api_count(:daily), do: do_api_count(:days)
  def api_count(:weekly), do: do_api_count(:weeks)
  def api_count(:monthly), do: do_api_count(:months)
  def active_api_accounts(:daily), do: do_active_count(:days)
  def active_api_accounts(:weekly), do: do_active_count(:weeks)
  def active_api_accounts(:monthly), do: do_active_count(:months)

  defp do_api_count(period) do
    since = Common.since(1, period)

    __MODULE__
    |> where([a], a.time >= ^since)
    |> where([a], a.is_internal == false)
    |> Repo.aggregate(:count)
  end

  defp do_active_count(period) do
    since = Common.since(1, period)
    __MODULE__
    |> select([a], count(a.account_id, :distinct))
    |> where([a], a.time >= ^since)
    |> where([a], a.is_internal == false)
    |> Repo.one()
  end

  def register_api_hit(account_id) do
    account = Backend.Projections.get_account!(account_id)

    Backend.Repo.insert(%__MODULE__{
      id: Domain.Id.new(),
      time: NaiveDateTime.utc_now(),
      account_id: account_id,
      is_internal: account.is_internal
    })
  end

  def cleanup() do
    Common.cleanup(__MODULE__)
  end
end
