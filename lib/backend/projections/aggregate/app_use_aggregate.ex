defmodule Backend.Projections.Aggregate.AppUseAggregate do
  use Ecto.Schema

  @primary_key false
  schema "aggregate_app_use" do
    field :id, :string
    field :time, :naive_datetime_usec
    field :user_id, :string
    field :app_type, :string
    field :is_internal, :boolean
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Aggregate.Common

  def active_slack_users(:daily), do: do_active_count(:days, :slack)
  def active_slack_users(:weekly), do: do_active_count(:weeks, :slack)
  def active_slack_users(:monthly), do: do_active_count(:months, :slack)
  def active_teams_users(:daily), do: do_active_count(:days, :teams)
  def active_teams_users(:weekly), do: do_active_count(:weeks, :teams)
  def active_teams_users(:monthly), do: do_active_count(:months, :teams)

  defp do_active_count(period, app_type) do
    since = Common.since(1, period)
    string_app_type = Atom.to_string(app_type)

    __MODULE__
    |> select([a], count(a.user_id, :distinct))
    |> where([a], a.time >= ^since)
    |> where([a], a.is_internal == false)
    |> where([a], a.app_type == ^string_app_type)
    |> Repo.one()
  end

  def cleanup() do
    Common.cleanup(__MODULE__)
  end
end
