defmodule Backend.Projections.Aggregate.NewSignupAggregate do
  use Ecto.Schema

  @primary_key false
  schema "aggregate_new_signups" do
    field :id, :string
    field :time, :naive_datetime_usec
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Aggregate.Common

  def new_signups(:daily), do: do_active_count(:days)
  def new_signups(:weekly), do: do_active_count(:weeks)
  def new_signups(:monthly), do: do_active_count(:months)

  defp do_active_count(period) do
    since = Common.since(1, period)
    __MODULE__
    |> select([a], count(a.id, :distinct))
    |> where([a], a.time >= ^since)
    |> Repo.one()
  end

  def cleanup() do
    Common.cleanup(__MODULE__)
  end
end
