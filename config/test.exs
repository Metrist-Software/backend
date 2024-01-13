import Config

config :backend, :crypt_repo, TestCryptRepo

config :backend, Backend.EventStore,
  username: "postgres",
  password: "postgres",
  database: "test_eventstore#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

config :backend, Backend.EventStore.Migration,
  username: "postgres",
  password: "postgres",
  database: "test_eventstore#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  schema: "migration",
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

config :backend, Backend.Repo,
  username: "postgres",
  password: "postgres",
  database: "test_projections#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :backend, Backend.EventStoreRewriter,
  admin_username: "postgres",
  admin_password: "postgres"

for mod <- [Backend.TelemetryRepo, Backend.TelemetryWriteRepo] do
  config :backend, mod,
    username: "postgres",
    password: "postgres",
    database: "test_telemetry#{System.get_env("MIX_TEST_PARTITION")}",
    hostname: "localhost",
    port: 5532,
    pool_size: 10,
    pool: Ecto.Adapters.SQL.Sandbox
end

config :backend, BackendWeb.Endpoint,
  http: [port: 4002],
  server: false

config :backend, Backend.RealTimeAnalytics,
  enable_blocked_check_details_state: true

config :logger, level: :error

config :backend, Backend.StatusPages.StatusPageObserverSupervisor,
  enabled: false
