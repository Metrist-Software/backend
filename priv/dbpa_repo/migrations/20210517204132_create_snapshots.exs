defmodule Backend.DbpaRepo.Migrations.CreateSnapshots do
  use Ecto.Migration

  def change do
    create table(:snapshots, primary_key: false) do
      add :name, :string, primary_key: true
      add :data, :jsonb

      timestamps()
    end
  end
end
