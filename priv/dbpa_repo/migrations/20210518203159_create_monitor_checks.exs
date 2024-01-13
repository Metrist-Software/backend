defmodule Backend.DbpaRepo.Migrations.CreateMonitorChecks do
  use Ecto.Migration

  def change do
    create table(:monitor_checks, primary_key: false) do
      add :logical_name, :string, primary_key: true
      add :monitor_logical_name, :string, primary_key: true
      add :name, :string
      add :is_private, :boolean, default: false

      timestamps()
    end

    create index(:monitor_checks, [:monitor_logical_name])
  end
end
