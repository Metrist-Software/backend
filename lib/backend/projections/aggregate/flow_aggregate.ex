defmodule Backend.Projections.Aggregate.FlowAggregate do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "aggregate_flow" do
    field :name, :string
    field :last_step, :string

    timestamps()
  end

  alias Domain.Flow.Events

  def project(multi, e = %Events.Created{}) do
    Ecto.Multi.insert(
      multi,
      :ecto_projector,
      %__MODULE__{
        id: e.id,
        name: e.name
      }
    )
  end

  def project(multi, e = %Events.StepCompleted{}) do
    change =
    __MODULE__
    |> Backend.Repo.get(e.id)
    |> Ecto.Changeset.change(last_step: e.step)

    Ecto.Multi.update(multi, :ecto_projector, change)
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Aggregate.Common

  def flow_stats(name, :daily), do: do_flow_stats(:days, name)
  def flow_stats(name, :weekly), do: do_flow_stats(:weeks, name)
  def flow_stats(name, :monthly), do: do_flow_stats(:months, name)

  defp do_flow_stats(period, name) do
    since = Common.since(1, period)

    Repo.all(from a in __MODULE__,
      where: a.name == ^name and a.inserted_at >= ^since,
      group_by: a.last_step,
      select: {a.last_step, count(a.id)})
    |> Map.new()
  end
end
