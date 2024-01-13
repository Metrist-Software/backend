defmodule Backend.DbpaRepo.Migrations.CreateMonitorToggledEvents do
  use Ecto.Migration

  def change do
    create table(:monitor_toggled_events, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :state, :string

      timestamps()
    end
    create index(:monitor_toggled_events, [:monitor_logical_name])
  end
end
