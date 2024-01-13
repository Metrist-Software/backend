import Config

config :backend, BackendWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

#config :backend, :metrics_reporting_module, TelemetryMetricsCloudwatch

# The rest of the configuration is resolved at run-time through Elixir's release scripts
# and can be found in releases.exs
