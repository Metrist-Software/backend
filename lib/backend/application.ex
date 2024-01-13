defmodule Backend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(type, args) do
    configure_logging()

    # If we have an env, we're running under Mix and we take it (see mix.exs, which is where we inject it).
    # Otherwise, we're in prod.
    env = case args do
            [] -> :prod
            [env] -> env
          end

    :gen_event.add_handler(:alarm_handler, Backend.MemsupAlarmHandler, :ok)

    IO.puts("=== Starting backend application, type=#{type}, env=#{env}")
    Domain.CryptRepo.current.initialize()
    display_build_txt()
    Signals.start()
    configure_api_token()
    configure_auth0()
    configure_slack()
    configure_teams()
    configure_dist_signing_key()
    configure_feedback()
    configure_hubspot()
    configure_google_analytics()
    configure_twitter()
    configure_datadog_oauth2_client()

    children = [
      Backend.PromEx,
      Backend.App.DelayingSupervisor,
      Backend.Repo,
      Backend.TelemetryRepo,
      Backend.TelemetryWriteRepo,
      {Task.Supervisor, name: Backend.TaskSupervisor}
    ]

    # A minimal start is mostly to be able to do database manipulations in some
    # peace and quiet, without processes barfing because the proverbial rug
    # got pulled from underneath them.
    children =
      if System.get_env("BACKEND_MINIMAL_START") != nil do
        Logger.warn("+++ WARNING: DOING MINIMAL START. THIS IS ONLY OK DURING SPECIAL CIRCUMSTANCES LIKE DB MIGRATIONS!")
        children
      else
        Logger.info("Doing regular startup")

        children = (children ++
          [
            Backend.PubSub.spec(),
            BackendWeb.Telemetry,
            #Backend.AccountAnalytics,
            Backend.AgentMonitor.Supervisor,
            Backend.MinuteClock,
            Backend.StatusPages.StatusPageObserverSupervisor,
            Backend.CommandedSupervisor,
          ]
        )
        |> maybe_start_rta()
        |> maybe_start_twitter_supervisor()
        |> maybe_start_scheduled_metrics()
        |> maybe_start_libcluster()
        |> maybe_start_mnesia()
        |> maybe_start_telemetry_copy()
        # Not ready to be used on a deployed instance, but uncommenting here will have the rewrite process run
        # |> maybe_start_event_store_rewrite()

        # Supervisor process startup is synchronous and in order. So by starting Endpoint last,
        # we don't emit a healthy response on /internal/health until everything above has been
        # successfully spun up.
        children ++ [BackendWeb.Endpoint]
      end


    opts = [strategy: :one_for_one, name: Backend.Supervisor, max_restarts: 35]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp configure_logging do
    Logger.add_backend(Sentry.LoggerBackend)
    Backend.LogFilter.setup_filters()
  end

  defp configure_api_token do
    token =
      case get_secret("canary-internal/api-token") do
        nil ->
          "fake-token-for-dev"

        secret ->
          secret
          |> Jason.decode!()
          |> Map.get("token")
      end

    # We use it both for verifying incoming requests (in web) and
    # for authenticating outgoing requests, cleanest is to give both
    # apps the token.
    Application.put_env(:backend_web, :api_token, token)
    Application.put_env(:backend, :api_token, token)
  end

  def configure_auth0 do
    case get_maybe_local_secret("auth0/api-token") do
      nil -> maybe_load_auth0_from_env()
      secret -> load_auth0_from_secret(secret)
    end
  end

  defp maybe_load_auth0_from_env do
    if System.get_env("AUTH0_HOST") do
      Application.put_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth,
        domain: System.get_env("AUTH0_HOST"),
        client_id: System.get_env("AUTH0_CLIENTID"),
        client_secret: System.get_env("AUTH0_CLIENTSECRET"),
        default_scope: "openid profile email offline_access"
      )

      # Needed for logout.
      Application.put_env(:backend, :auth0_client_id, System.get_env("AUTH0_CLIENTID"))

      Application.put_env(:backend, :auth0_m2m_secrets, %{
        host: System.get_env("AUTH0_HOST"),
        m2m_client_id: System.get_env("AUTH0_M2M_CLIENTID"),
        m2m_client_secret: System.get_env("AUTH0_M2M_M2MSECRET"),
        m2m_audience: System.get_env("AUTH0_M2M_AUDIENCE")
      })
      Backend.Auth.Auth0.init()
    else
      Logger.warning("AUTH0_HOST environment variable not set, not configuring Auth0 from env")
    end
  end

  defp load_auth0_from_secret(secret) do
    case secret do
      nil ->
        Logger.warning("Nil secret, not configuring Auth0")
      secret ->
        auth0_secrets = Jason.decode!(secret)

        Application.put_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth,
          domain: auth0_secrets["host"],
          client_id: auth0_secrets["clientId"],
          client_secret: auth0_secrets["clientSecret"],
          default_scope: "openid profile email offline_access"
        )

        # Needed for logout.
        Application.put_env(:backend, :auth0_client_id, auth0_secrets["clientId"])

        Application.put_env(:backend, :auth0_m2m_secrets, %{
          host: auth0_secrets["host"],
          m2m_client_id: auth0_secrets["m2mClientId"],
          m2m_client_secret: auth0_secrets["m2mSecret"],
          m2m_audience: auth0_secrets["m2maudience"]
        })
    end
    Backend.Auth.Auth0.init()
  end

  defp configure_slack() do
    case get_secret("slack/api-token") do
      nil ->
        Logger.warning("Nil secret, not configuring Slack")
      secret ->
        slack_secrets = Jason.decode!(secret)
        Application.put_env(:backend, :slack_client_id, slack_secrets["clientId"])
        Application.put_env(:backend, :slack_client_secret, slack_secrets["clientSecret"])
    end
  end

  defp configure_teams() do
    case get_secret("canary-teams/api-token") do
      nil ->
        Logger.warning("Nil secret, not configuring Teams")
      secret ->
        teams_secrets = Jason.decode!(secret)
        Application.put_env(:backend, :teams, %{
          auth_client_id: teams_secrets["auth-clientid"],
          auth_client_secret: teams_secrets["auth-clientsecret"],
          app_id: teams_secrets["app-id"],
          app_password: teams_secrets["app-password"],
        })
    end
  end

  defp configure_dist_signing_key() do
    case get_secret("m2m-s3-shared-dist-writer/aws-keys/") do
      nil ->
        Logger.warning("Nil secret, not configuring Distributions")
      secret ->
        aws_key = Jason.decode!(secret)
        Application.put_env(:backend, :distributions_signing_key,
          access_key_id: aws_key["aws_access_key_id"],
          secret_access_key: aws_key["aws_secret_access_key"])
    end
  end

  def configure_hubspot()  do
    case get_secret("canary-internal/hubspot-api-key") do
      nil ->
          Logger.warning("Nil secret, not configuring Hubspot App Token")
      secret ->
        token = Jason.decode!(secret) |> Map.fetch!("appToken")
        Application.put_env(:backend, :hubspot_app_token, token)
    end
  end

  def configure_feedback() do
    case get_secret("backend/jira-feedback-apikey") do
      nil ->
        Logger.warning("Nil secret, not configuring feedback to Jira")
      secret ->
        decoded = Jason.decode!(secret)
        Application.put_env(:backend, :feedback_key, decoded)
    end
  end

  def configure_datadog_oauth2_client() do
    case get_secret("datadog/oauth2-client") do
      nil ->
        Logger.warning("Nil secret, not configuring feedback to Jira")
      secret ->
        decoded = Jason.decode!(secret)
        Application.put_env(:backend, :dd_oauth2_client, [
          client_secret: decoded["confidential_client_secret"],
          client_id: decoded["confidential_client_id"],
          redirect_uri: decoded["confidential_redirect_uri"]
        ])
    end
  end

  def configure_google_analytics() do
    tag =
      if is_prod?() do
        {"ASPbkwWl4UtIlhclkCgd9A", "env-1"}
      else
        {"_WsvQG62IBE2foskERPjUA", "env-3"}
      end
    Application.put_env(:backend, :google_analytics_tag, tag)
  end
  def get_google_analytics_tag(), do: Application.get_env(:backend, :google_analytics_tag)

  def configure_twitter() do
    case get_secret("twitter/api-token") do
      nil ->
        Logger.warning("Nil secret, Twitter client will fail")
      secret ->
        decoded = Jason.decode!(secret)
        Application.put_env(:backend, :twitter_bearer_token, decoded["bearer_token"])
    end
  end

  def get_secret(path) do
    case System.get_env("SECRETS_NAMESPACE") do
      nil ->
        Logger.warning("No SECRETS_NAMESPACE found, not fetching secret #{path}")
        nil
      env ->
        get_secret(path, env)
    end
  end

  def get_secret(path, namespace, region \\ nil) do
    region = region || System.get_env("AWS_REGION") || "us-east-1"
    IO.puts("get_secret(#{namespace}#{path}) from #{region}")
    # We may be called in various stages of the life cycle, including really
    # early, so make sure that what ExAws needs is up and running.
    [:ex_aws_secretsmanager, :hackney, :jason]
    |> Enum.map(&Application.ensure_all_started/1)

    case do_get_secret(path, namespace, region) do
      {:ok, %{"SecretString" => secret}} -> secret
      {:error, _} -> nil
    end
  end

  def do_get_secret(path, namespace, region) do
    "#{namespace}#{path}"
    |> ExAws.SecretsManager.get_secret_value()
    |> ExAws.request(region: region)
  end

if Mix.env == :dev do
  def get_maybe_local_secret(path), do: get_secret(path, "/local/")
else
  def get_maybe_local_secret(path), do: get_secret(path)
end

  def get_json_secret(path, namespace, region \\ nil) do
    path
    |> get_secret(namespace, region)
    |> Jason.decode!()
  end

  def do_aws_request(request) do
    region = System.get_env("AWS_REGION") || "us-east-1"
    ExAws.request(request, region: region)
  end

  def display_build_txt() do
    build_txt = Path.join([Application.app_dir(:backend), "priv", "static", "build.txt"])
    if File.exists?(build_txt) do
      contents = File.read!(build_txt)
      Logger.info("Starting build: #{contents}")
    end
  end

  def maybe_start_telemetry_copy(children) do
    case System.get_env("TELEMETRY_TOLOCAL_COPY_SOURCE_ENV") do
      nil ->
        Logger.info("TELEMETRY_TOLOCAL_COPY_SOURCE_ENV NOT FOUND - Not enabling telemetry to local copy")
        children

      source ->
        Logger.info("Enabling telemetry to local copy with source of #{source}")

        timescaleSecrets = get_secret("timescaledb/tokens", source)
        |> Jason.decode!()
        children ++ [{Backend.TelemetryToLocal, %{ source: source, connectionParams:
                    [
                      hostname: timescaleSecrets["readHost"],
                      username: timescaleSecrets["username"],
                      password: timescaleSecrets["password"],
                      database: timescaleSecrets["database"],
                      port: timescaleSecrets["port"], ssl: true
                    ]}
                    }]
    end
  end

  if Mix.env == :test do
    def maybe_start_scheduled_metrics(children), do: children
    def maybe_start_twitter_supervisor(children), do: children
    def maybe_start_rta(children), do: children
    def maybe_start_mnesia(children), do: children
  else
    def maybe_start_scheduled_metrics(children),
      do: children ++ [
        Backend.ScheduledMetrics,
        Backend.MonitorAgeTelemetry,
        Backend.MonitorErrorTelemetry
      ]
    def maybe_start_twitter_supervisor(children),
      do: children ++ [Backend.Twitter.Supervisor]
    def maybe_start_rta(children),
      do: children ++ [Backend.RealTimeAnalytics.SwarmSupervisor]
    def maybe_start_mnesia(children),
      do: children ++ [Backend.Mnesia]

  end
  # It's easy enough for now to manually start.
  def maybe_start_event_store_rewrite(children), do: children
  def maybe_start_event_store_rewrite(children, _disabled = false) do
    children ++ [
      {Backend.EventStoreRewriter.Supervisor,
       [migration: Backend.EventStoreRewriter.Migrations.EventsV2]}
    ]
  end

  def maybe_start_libcluster(children) do
    case Application.get_env(:libcluster, :topologies) do
      nil ->
        Logger.info("Not starting libcluster, no topologies defined")
        children
      topologies ->
        Logger.info("Starting libcluster with #{inspect topologies}")
        children ++ [{Cluster.Supervisor, [topologies, [name: Backend.ClusterSupervisor]]}]
    end
  end

  def is_prod? do
    String.starts_with?(System.get_env("ENVIRONMENT_TAG") || "local", "prod")
  end
end
