import Config

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, :system, 30}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, {:awscli, :system, 30}, :instance_role]

# The actual repositories are configured in dev/test/runtime.exs
config :backend,
  ecto_repos: [Backend.Repo, Backend.TelemetryRepo, Backend.TelemetryWriteRepo]

config :backend, BackendWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base:
    "------------------- fake secret key base for development --------------------",
  render_errors: [view: BackendWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Backend.PubSub,
  live_view: [signing_salt: "ZtGmZoZJ"],
  reloadable_compilers: [:phoenix, :domo_compiler] ++ Mix.compilers() ++ [:domo_phoenix_hot_reload]

config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :esbuild,
  version: "0.16.17",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :phoenix, :json_library, Jason

config :phoenix_inline_svg, dir: "priv/static/svg"

config :backend,
  event_stores: [Backend.EventStore]

config :ueberauth, Ueberauth,
  providers: [
    auth0: {Ueberauth.Strategy.Auth0, [callback_params: ["invite_id", "slack_team_id", "redirect_monitor"]]}
  ]

config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: "fake domain",
  client_id: "fake id",
  client_secret: "fake secret"

config :backend, Distributions,
  bucket_name: "canary-shared-dist",
  region: "us-west-2"

config :backend, :dd_oauth2_client, [
  client_secret: nil,
  client_id: nil,
  redirect_uri: nil
]

config :hammer,
  backend: {Hammer.Backend.ETS,
    [expiry_ms: 60_000 * 60 * 4,
     cleanup_interval_ms: 60_000 * 10]}


# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
