defmodule Backend.DbpaRepo.Migrations.AddMonitors do
  use Ecto.Migration

  def change do
    create table(:monitors, primary_key: false) do
      add :logical_name, :string, primary_key: true
      add :name, :string
      add :last_analysis_run_at, :timestamp
      add :last_analysis_run_by, :string

      timestamps()
    end
  end
end
