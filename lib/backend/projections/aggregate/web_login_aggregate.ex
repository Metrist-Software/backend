defmodule Backend.Projections.Aggregate.WebLoginAggregate do
  use Ecto.Schema

  @primary_key false
  schema "aggregate_web_login" do
    field :id, :string
    field :time, :naive_datetime_usec
    field :user_id, :string
    field :is_internal, :boolean
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Aggregate.Common

  def active_web_users(:daily), do: do_active_count(:days)
  def active_web_users(:weekly), do: do_active_count(:weeks)
  def active_web_users(:monthly), do: do_active_count(:months)

  defp do_active_count(period) do
    since = Common.since(1, period)

    __MODULE__
    |> select([a], count(a.user_id, :distinct))
    |> where([a], a.time >= ^since)
    |> where([a], a.is_internal == false)
    |> Repo.one()
  end

  def cleanup() do
    Common.cleanup(__MODULE__)
  end
end
