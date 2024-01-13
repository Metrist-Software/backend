import Config

config :backend, :crypt_repo, Backend.Crypto.SecretsManagerRepo

config :backend, Backend.EventStore,
  username: "postgres",
  password: "postgres",
  database: "local_eventstore",
  hostname: "localhost",
  pool_size: 10

config :backend, Backend.EventStore.Migration,
  username: "postgres",
  password: "postgres",
  database: "local_eventstore",
  schema: "migration",
  hostname: "localhost",
  pool_size: 10

config :backend, Backend.Repo,
  username: "postgres",
  password: "postgres",
  database: "local_projections",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :backend, Backend.EventStoreRewriter,
  admin_username: "postgres",
  admin_password: "postgres"

for mod <- [Backend.TelemetryRepo, Backend.TelemetryWriteRepo] do
  config :backend, mod,
    username: "postgres",
    password: "postgres",
    database: "local_telemetry",
    hostname: "localhost",
    port: 5532,
    pool_size: 10
end

port = (System.get_env("PORT") || "4443") |> String.to_integer()

config :backend, BackendWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    npx: [
      "tailwindcss",
      "--input=css/app.css",
      "--output=../priv/static/assets/app.css",
      "--postcss",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  https: [
    port: port,
    cipher_suite: :strong,
    keyfile: "priv/localhost+2-key.pem",
    certfile: "priv/localhost+2.pem"
  ]

# Watch static and templates for browser reloading.
config :backend, BackendWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"priv/en.json",
      ~r"lib/backend_web/(live|views|components)/.*(ex)$",
      ~r"lib/backend_web/templates/.*(eex)$"
    ]
  ]

config :backend, Backend.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :libcluster,
  debug: true,
  topologies: [
    local_epmd: [
      strategy: Elixir.Cluster.Strategy.LocalEpmd
    ]
  ]

# Mostly for debugging.
# config :backend, :metrics_reporting_module, Telemetry.Metrics.ConsoleReporter

# Do not include metadata in development logs
config :logger, :console, format: "$time [$level] $message\n", level: :info

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Slack API token at compile time
config :backend, slack_api_token: System.get_env("SLACK_API_TOKEN")
config :backend, slack_signing_secret: System.get_env("SLACK_SIGNING_SECRET")

config :joken, default_signer: System.get_env("CANARY_API_TOKEN", "local_signing_secret")

# Hubspot App Token at compile time
config :backend, hubspot_app_token: System.get_env("HUBSPOT_APP_TOKEN")

config :backend, Backend.RealTimeAnalytics,
  enabled: System.get_env("RTA_ENABLED", "true") == "true",
  enable_blocked_check_details_state: System.get_env("ENABLE_ISSUES_STATE"),
  rta_startup_attempts: String.to_integer(System.get_env("RTA_STARTUP_ATTEMPTS", "10"))

config :stripity_stripe,
  api_key: System.get_env("STRIPE_PRIVATE_API_KEY"),
  public_key: System.get_env("STRIPE_PUBLIC_API_KEY")

config :backend, Backend.StatusPages.StatusPageObserverSupervisor,
  enabled: System.get_env("ENABLE_STATUS_PAGE_OBSERVERS", "false") == "true"

config :backend, BackendWeb.LoginLive,
  open_id_connection_name: "dev1-slack-openidconnect"

config :open_api_spex, :cache_adapter, OpenApiSpex.Plug.NoneCache
