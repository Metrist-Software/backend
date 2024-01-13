defmodule Backend.Repo.Migrations.AddFlowAggregate do
  use Ecto.Migration

  def change do
    create table(:aggregate_flow, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :last_step, :string

      timestamps()
    end
    # We usually will display records from a single type of flow started
    # during a certain time period.
    create index(:aggregate_flow, [:name, :inserted_at])
  end
end
