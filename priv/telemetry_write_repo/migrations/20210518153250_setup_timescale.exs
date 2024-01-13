defmodule Backend.TelemetryRepo.Migrations.SetupTimescale do
  use Ecto.Migration

  # Timescale Cloud already has all of this, so never run this against Mix prod
  # or in prod (when Mix is not available).
  if Application.get_application(Mix) != nil && Mix.env in [:dev, :test] do
    def up do
      execute "CREATE EXTENSION IF NOT EXISTS timescaledb;"
      execute """
          CREATE TABLE IF NOT EXISTS monitor_telemetry (
          time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          monitor_id text NULL,
          account_id text NULL,
          instance_id text NULL,
          check_id text NULL,
          value double PRECISION NULL
          );
      """

      execute "SELECT create_hypertable('monitor_telemetry','time', if_not_exists => TRUE);"

      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_time_idx on monitor_telemetry (time DESC);"
      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_monitor_id_time_idx on monitor_telemetry (monitor_id, time DESC);"
      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_monitor_id_account_id_time_idx on monitor_telemetry (monitor_id, account_id, time DESC);"
      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_account_id_time_idx on monitor_telemetry (account_id, time DESC);"
      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_instance_id_time_idx on monitor_telemetry (instance_id, time DESC);"
      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_monitor_id_check_id_time_idx on monitor_telemetry (monitor_id, check_id, time DESC);"
      execute "CREATE INDEX IF NOT EXISTS monitor_telemetry_monitor_id_instance_id_time_idx on monitor_telemetry (monitor_id, instance_id, time DESC);"
    end
  else
    def up do
    end
  end
end
