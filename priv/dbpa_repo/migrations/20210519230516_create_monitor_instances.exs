defmodule Backend.DbpaRepo.Migrations.CreateMonitorInstances do
  use Ecto.Migration

  def change do
    create table(:monitor_instances, primary_key: false) do
      add :monitor_logical_name, :string, primary_key: true
      add :instance_name, :string, primary_key: true
      add :last_report, :naive_datetime_usec
      add :check_last_reports, :jsonb

      timestamps()
    end

    create index(:monitor_instances, [:monitor_logical_name])
  end
end
