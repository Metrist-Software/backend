defmodule Backend.TelemetryWriteRepo.Migrations.SetRetention do
  use Ecto.Migration

  def up do
    execute "SELECT add_retention_policy('monitor_telemetry', INTERVAL '90 days')"
  end

  def down do
    execute "SELECT remove_retention_policy('monitor_telemetry')"
  end
end
