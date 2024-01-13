defmodule Backend.DbpaRepo.Migrations.CreateMonitorErrors do
  use Ecto.Migration

  def change do
    create table(:monitor_errors, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :check_logical_name, :string
      add :instance_name, :string
      add :message, :text
      add :time, :naive_datetime_usec

      timestamps()
    end

    create index(:monitor_errors, [:time])
  end
end
