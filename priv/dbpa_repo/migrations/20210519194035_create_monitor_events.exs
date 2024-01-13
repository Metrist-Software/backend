defmodule Backend.DbpaRepo.Migrations.CreateMonitorEvents do
  use Ecto.Migration

  def change do
    create table(:monitor_events, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :check_logical_name, :string
      add :instance_name, :string
      add :state, :string
      add :message, :text
      add :start_time, :naive_datetime_usec
      add :end_time, :naive_datetime_usec

      timestamps()
    end

    create index(:monitor_events, [:end_time])
  end
end
