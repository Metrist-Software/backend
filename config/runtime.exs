import Config

# For "production" envs, AWS should be setup correctly, either with
# env vars or the instance-local injection. We fetch all the important
# stuff right here from AWS Secrets Manager.

if config_env() == :prod do
  namespace =
    System.get_env("SECRETS_NAMESPACE") ||
      raise """
      Environment variable SECRETS_NAMESPACE is missing. Set
      it to '/dev1/', '/prod/', or something similar.
      """

  # For running migrations, we want to login as the owner.
  dba_prefix = if System.get_env("USE_DB_ADMIN"), do: "admin_", else: ""

  # Configure the event store

  {:ok, db_config} =
    "rds/eventstore-user"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  config :backend, Backend.EventStore,
    username: db_config["#{dba_prefix}username"],
    password: db_config["#{dba_prefix}password"],
    database: db_config["dbname"],
    hostname: db_config["host"],
    pool_size: String.to_integer(db_config["pool_size"])

  # Configure second event store for snapshot migrations. Same database as primary store, but with a different schema
  config :backend, Backend.EventStore.Migration,
    username: db_config["#{dba_prefix}username"],
    password: db_config["#{dba_prefix}password"],
    database: db_config["dbname"],
    hostname: db_config["host"],
    schema: "migration",
    pool_size: String.to_integer(db_config["pool_size"])

  config :backend, Backend.EventStoreRewriter,
    admin_username: db_config["admin_username"],
    admin_password: db_config["admin_password"]

  # Configure the database where we keep projections and similar stuff.
  # FIXME the regular write user has dba privs, which we do not need.

  {:ok, db_config} =
    "rds/projections-user"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  config :backend, Backend.Repo,
    username: db_config["username"],
    password: db_config["password"],
    database: db_config["dbname"],
    hostname: db_config["host"],
    pool_size: String.to_integer(db_config["pool_size"])

  {:ok, timescaledb_config} =
    "timescaledb/tokens"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  config :backend, Backend.TelemetryRepo,
    username: timescaledb_config["username"],
    password: timescaledb_config["password"],
    database: timescaledb_config["database"],
    hostname: timescaledb_config["readHost"],
    port: timescaledb_config["port"],
    ssl: true,
    pool_size: String.to_integer(timescaledb_config["pool_size"])

  config :backend, Backend.TelemetryWriteRepo,
    username: timescaledb_config["#{dba_prefix}username"],
    password: timescaledb_config["#{dba_prefix}password"],
    database: timescaledb_config["database"],
    hostname: timescaledb_config["writeHost"],
    port: timescaledb_config["port"],
    ssl: true,
    pool_size: String.to_integer(timescaledb_config["pool_size"])

  # For Phoenix, configure our secret key base.

  env =
    System.get_env("ENVIRONMENT_TAG") ||
      raise """
      Environment variable ENVIRONMENT_TAG is missing. Set
      it to 'dev1', 'prod', or something similar.
      """

  {:ok, %{"SecretString" => secret_key_base}} =
    "#{namespace}phoenix/secret-key-base"
    |> ExAws.SecretsManager.get_secret_value()
    |> Backend.Application.do_aws_request()

  # Especially LiveView is quite sensitive to the correct setting here.
  host =
    case env do
      "prod" -> "app.metrist.io"
      other -> "app-#{other}.metrist.io"
    end

  kinsta_host = case env do
    "prod" -> "metrist.io"
    _other -> "staging-metrist.kinsta.cloud"
  end

  port = 80

  config :backend, BackendWeb.Endpoint,
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      transport_options: [socket_opts: [:inet6]]
    ],
    url: [
      host: host,
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true,
    check_origin: [
      "//#{host}",
      "//#{kinsta_host}"
    ]

  topology =
    if System.get_env("LOCAL_CLUSTER") != nil do
      [
        local_epmd: [
          strategy: Elixir.Cluster.Strategy.LocalEpmd
        ]
      ]
    else
      [
        core: [
          strategy: ClusterEC2.Strategy.Tags,
          config: [
            ec2_tagname: "cm-clustername"
          ]
        ]
      ]
    end

  # Clustering, in production we use DNS powered by AWS service discovery/cloudmap
  # Note that this means that we have to show up as healthy before cluster is formed,
  # if that is not ok we can always stash ourselves in a DB table and use that to
  # find the other hosts.
  # If we run from Sup, then we're fully connected and can use Gossip. DNS Poll will
  # still deliver nodes in ECS but we cannot talk to them.
  config :libcluster,
    # Not a lot and might be helpful
    debug: true,
    topologies: topology

  {:ok, slack_config} =
    "slack/api-token"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  config :backend, slack_api_token: slack_config["token"]
  config :backend, slack_signing_secret: slack_config["signingSecret"]

  {:ok, grafana_credentials} =
    "grafana/credentials"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  grafana_definition =
    if System.get_env("DISABLE_GRAFANA") != nil do
      :disabled
    else
      [
        host: "https://metrist.grafana.net",
        auth_token: grafana_credentials["GRAFANA_EDITOR_API_TOKEN"],
        # true # This is an optional setting and will default to `true`
        upload_dashboards_on_start: true
      ]
    end

  config :backend, Backend.PromEx,
    disabled: false,
    manual_metrics_start_delay: :no_delay,
    drop_metrics_groups: [],
    # grafana: :disabled,
    grafana: grafana_definition,
    metrics_server: :disabled

  {:ok, internal_token} =
    "canary-internal/api-token"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  config :joken, default_signer: internal_token["token"]

  config :backend,
    hubspot_app_token:
      "canary-internal/hubspot-api-key"
      |> Backend.Application.get_json_secret(namespace)
      |> Map.fetch!("appToken")

  config :backend,
    enable_monitor_running_alerts: env == "prod",
    crypt_repo: Backend.Crypto.SecretsManagerRepo,
    encryption_key_env_tag: env,
    encryption_key_secret_prefix: "/#{env}/encryption-keys"

  config :backend, Backend.RealTimeAnalytics,
    enabled: true,
    alerting_topic_arn: System.get_env("ALERTING_SNS_TOPIC_ARN"),
    enable_blocked_check_details_state: true,
    rta_startup_attempts: 10

  {:ok, stripe_tokens} =
    "stripe-internal/api-token"
    |> Backend.Application.get_secret(namespace)
    |> Jason.decode()

  config :stripity_stripe,
    api_key: stripe_tokens["private_key"],
    public_key: stripe_tokens["public_key"]

  config :backend, Backend.StatusPages.StatusPageObserverSupervisor,
    enabled: true

  open_id_connection_name =
    case env do
      "prod" -> "prod-slack-openidconnect"
      _ -> "dev1-slack-openidconnect"
    end

  config :backend, BackendWeb.LoginLive,
    open_id_connection_name: open_id_connection_name

  config :hammer,
    backend: {Hammer.Backend.Mnesia,
              [expiry_ms: 60_000 * 60 * 4,
               cleanup_interval_ms: 60_000 * 10]}

  {:ok, sentry_data} =
  "internal/sentry"
  |> Backend.Application.get_secret(namespace)
  |> Jason.decode()

  config :sentry,
    dsn: sentry_data["ingestUrl"],
    environment_name: System.get_env("ENVIRONMENT_TAG"),
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    before_send_event: {Backend.Sentry, :before_send},
    included_environments: ~w(dev1 prod)

  config :logger, Sentry.LoggerBackend,
    capture_log_messages: true
end
