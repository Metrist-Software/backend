defmodule Backend.TelemetryWriteRepo.Migrations.AddMonitorEventsLogicalNameInsertedAtIndex do
  use Ecto.Migration

  def change do
    drop_if_exists index(:monitor_events, [:monitor_logical_name, :inserted_at])
    create index(:monitor_events, [:monitor_logical_name, :start_time, :end_time])
  end
end
