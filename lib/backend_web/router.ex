defmodule BackendWeb.Router do
  use BackendWeb, :router
  require Logger

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {BackendWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json", "txt"]
    plug :fetch_session
    plug :check_api_token
  end

  pipeline :swagger_api do
    plug OpenApiSpex.Plug.PutApiSpec, module: BackendWeb.API.ApiSpec
  end

  pipeline :internal_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :check_internal_api_token
  end

  pipeline :public_api do
    plug :accepts, ["json"]
  end

  pipeline :webhook do
    # It's possible that Plug.Parsers didn't get the body because it was not a parseable message
    # In that case, we have to grab it here as body can only be read once
    # This will work for other webhook types such as text/plain, text/xml or anything else Plug.Parsers doesn't parse
    plug :maybe_get_body
  end

  pipeline :dd do
    plug :allow_iframe
  end

  pipeline :slack do
    plug :maybe_get_body
    plug :validate_slack_signature
  end

  pipeline :require_user do
    plug :require_user_plug
  end
  pipeline :require_datadog_user do
    plug :require_datadog_user_plug
  end
  pipeline :datadog_auth do
    plug :datadog_auth_plug
  end
  pipeline :require_new_user do
    plug :require_new_user_plug
  end
  pipeline :require_no_user do
    plug :require_no_user_plug
  end
  pipeline :require_unverified_user do
    plug :require_unverified_user_plug
  end
  pipeline :require_admin_user do
    plug :require_admin_user_plug
  end
  pipeline :require_not_read_only_user do
    plug :require_not_read_only_user_plug
  end

  pipeline :internal_only do
    plug :internal_only_plug
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/internal" do
    pipe_through :internal_only

    get "/health", BackendWeb.HealthController, :index
    get "/metrics", PromEx.Plug, prom_ex_module: Backend.PromEx, path: "/internal/metrics"
  end

  # Stuff that requires a logged in user. Most routes go here.
  scope "/", BackendWeb do
    pipe_through :browser
    pipe_through :require_user

    live_session :user, on_mount: {BackendWeb.InitAssigns, :user} do
      live "/", MonitorsLive, :index
      get "/monitors", RedirectController, :index, assigns: %{to: "/"}
      live "/monitors/data/", MonitorsData
      live "/monitors/:monitor/data/", MonitorsData
      live "/monitors/errors/", MonitorsErrors
      live "/monitors/:monitor/errors/", MonitorsErrors
      live "/monitors/alerting/", MonitorAlertingLive
      live "/monitors/:monitor/alerting", MonitorAlertingLive
      live "/monitors/subscription-history", MonitorsSubscriptionHistoryLive
      live "/monitors/:monitor/subscription-history", MonitorsSubscriptionHistoryLive
      live "/monitors/issues/", MonitorIssuesLive, :list_issues
      live "/monitors/:monitor/issues/", MonitorIssuesLive, :monitor_issues
      live "/monitors/:monitor", MonitorDetailLive
      live "/monitors/:monitor/report", MonitorReportLive
      live "/monitors/:monitor/checks/:check", MonitorCheckLive
      live "/apps", AppsLive
      live "/apps/teams", AppsTeamsLive, :connect
      live "/apps/teams/complete", AppsTeamsLive, :complete
      live "/apps/teams/failed", AppsTeamsLive, :failed
      live "/apps/slack", AppsSlackLive, :start
      live "/apps/slack/confirm", AppsSlackLive, :confirm
      live "/apps/slack/complete", AppsSlackLive, :complete
      live "/apps/slack/failed", AppsSlackLive, :failed
      live "/docs", DocsLive
      live "/docs/:path", DocsLive
      live "/distributions", DistributionsLive, :index
      live "/distributions/*path", DistributionsLive
      live "/users", UsersLive
      live "/profile", ProfileLive
      get "/auth/unspoof", AuthController, :unspoof
    end
  end

  scope "/", BackendWeb do
    pipe_through :browser
    pipe_through :require_not_read_only_user

    live_session :not_read_only_user, on_mount: {BackendWeb.InitAssigns, :not_read_only_user} do
        live "/configure", MonitorsLive, :configure
        live "/billing", BillingLive
        live "/billing/complete", BillingCompleteLive
    end
  end

  # Stuff that requires a new user, iow everything part of signup
  # post user creation.
  scope "/", BackendWeb do
    pipe_through :browser
    pipe_through :require_new_user

    live_session :new_user, on_mount: {BackendWeb.InitAssigns, :new_user} do
      live "/signup/monitors", SignupLive, :monitors
    end
  end

  # "Everyone" (logged in status doesn't matter (no redirects))
  scope "/", BackendWeb do
    pipe_through :browser

    live_session :everyone, on_mount: {BackendWeb.InitAssigns, :everyone}, session: %{"demo" => true} do
      live "/demo", DemoMonitorsLive, :index
      live "/demo/issues", MonitorIssuesLive, :demo_list_issues
      live "/demo/:monitor", DemoMonitorDetailLive
      live "/demo/:monitor/issues/", MonitorIssuesLive, :demo_monitor_issues
    end
  end

  # Must be unique path per Datadog app as / is always hit for the controller
  scope "/dd-metrist", BackendWeb do
    pipe_through :dd
    pipe_through :browser
    pipe_through :require_datadog_user

    live_session :datadog do
      live "/", Datadog.ControllerLive
      live "/start", Datadog.StartLive
      live "/health", Datadog.HealthWidgetLive
      live "/synthetics-wizard", Datadog.SyntheticsWizardLive, :start
      live "/synthetics-wizard/configure-monitors", Datadog.SyntheticsWizardLive, :configure_monitors
      live "/synthetics-wizard/creating", Datadog.SyntheticsWizardLive, :creating
      live "/synthetics-wizard/complete", Datadog.SyntheticsWizardLive, :complete
      get  "/auth-check", Datadog.LoginController, :auth_check
    end
  end


  scope "/dd-metrist", BackendWeb do
    pipe_through :dd
    pipe_through :browser
    pipe_through :datadog_auth

    # Confidential OAuth client endpoints
    get  "/auth", Datadog.LoginController, :auth_request
    get  "/auth/callback", Datadog.LoginController, :auth_callback
    live "/auth/complete", Datadog.AuthCompleteLive

    # UI app auth endpoint
    get  "/auth-app", Datadog.LoginController, :auth_app
  end

  # Public stuff
  scope "/", BackendWeb do
    pipe_through :browser
    pipe_through :require_no_user

    live_session :public, on_mount: {BackendWeb.InitAssigns, :public} do
      live "/login", LoginLive
      live "/invites/:invite_id", LoginLive
      live "/login/signup", LoginLive, :signup
      live "/slack_login_retry/:slack_team_id/:redirect_monitor", SlackLoginRetryLive
      get "/signup", SignupController, :index
      get "/signup/register", SignupController, :index
      get "/signup/redirect/:connection", SignupController, :signup_redirect
      get "/subscriptions/unsubscribe", SubscriptionController, :delete
    end
  end

  scope "/slack_login", BackendWeb do
    # Does not pipe through :slack because :slack is for interaction within Slack
    # /slack_login is for the webapp side for login with Slack from Slack explore button
    pipe_through :browser
    get "/:slack_team_id/:redirect_monitor", SlackLoginController, :slack_login
  end

  # Auth stuff split in "for logged in" and "not for logged in"
  scope "/auth", BackendWeb do
    pipe_through :browser
    get "/logout", AuthController, :delete
    get "/reauth", AuthController, :reauth
  end
  scope "/auth", BackendWeb do
    pipe_through :browser
    pipe_through :require_no_user

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
  end

  scope "/verify", BackendWeb do
    pipe_through :browser
    pipe_through :require_unverified_user

    live_session :unverified_user, on_mount: {BackendWeb.InitAssigns, :user} do
      live "/", VerifyEmailLive
    end
  end

  # These are only to be accessed using a Metrist api token, not account tokens
  scope "/api", BackendWeb do
    pipe_through :internal_api
    get "/snapshot", SnapshotController, :get
    get "/snapshots/:account", SnapshotController, :list
    post "/command", CommandController, :post
  end

  scope "/api", BackendWeb do
    pipe_through :api
    get "/agent/run-config/:instance", AgentController, :run_config
    post "/agent/telemetry", AgentController, :telemetry
    post "/agent/error", AgentController, :error
    post "/agent/host_telemetry", AgentController, :host_telemetry
    post "/agent/monitor-alert", AgentController, :monitor_alert
    get "/webhook/:monitor/:instance/:uid", WebhookController, :get_by_uid
    # Scope customer-visible stuff with a version number, just in case. We
    # use 'v0' for new/experimental/may change stuff.
    scope "/v0" do
      pipe_through :swagger_api
      get "/monitor-status", MonitorStatusController, :get
      get "/monitor-config", MonitorConfigController, :get
      post "/monitor-config", MonitorConfigController, :post
      delete "/monitor-config/:monitor/:id", MonitorConfigController, :delete
      get "/monitor-telemetry", MonitorTelemetryController, :get
      get "/monitor-error", MonitorErrorController, :get
      get "/verify-auth", VerifyAuthController, :get
      get "/monitor-list", MonitorListController, :get
      get "/monitor-status-page-change", StatusPageChangeController, :get
      get "/monitor-check", MonitorCheckController, :get
      get "/monitor-instance", MonitorInstanceController, :get
      get "/issues", IssueController, :list_issues
      get "/issues/:issue_id/events", IssueController, :list_issue_events
    end
  end

  scope "/api", BackendWeb do
    pipe_through :public_api
    scope "/ov" do # "Obfuscated versioning"
      get "/11yDknDllDq4CffG1R7tXQp/cso/:cloud", LandingPageSupportController, :cloud_state_overview
    end
  end

  scope "/webhook", BackendWeb do
    pipe_through :webhook
    post "/:monitor/:instance", WebhookController, :receive
    get "/:monitor/:instance", WebhookController, :receive
  end

  scope "/slack", BackendWeb do
    pipe_through :slack
    post "/webhook", SlackController, :post_webhook
    post "/command", SlackController, :post_command
    post "/interact", SlackController, :post_interact
  end

  scope "/admin", BackendWeb do
    pipe_through :browser
    pipe_through :require_admin_user

    live_session :admin, on_mount: {BackendWeb.InitAssigns, :admin} do
      live "/", Admin.AdminLive
      live "/accounts", Admin.AccountsLive, :index
      live "/accounts/:id/free_trial_configure", Admin.AccountsLive, :free_trial_configure
      live "/metrics", Admin.MetricsLive
      get "/spoof/:account_id/:account_name", AuthController, :spoof
      live "/aggregate", Admin.Utilities.AggregateViewLive
      live "/edit_visible_monitors/:account_id", Admin.VisibleMonitorsLive
      live "/monitor-usage", Admin.Utilities.MonitorUsageLive
      live "/notices", Admin.Utilities.NoticesLive
      live "/snapshot", Admin.Utilities.SnapshotViewLive
      live "/rename-monitor", Admin.Utilities.RenameMonitor
      live "/rename-check", Admin.Utilities.RenameCheck
      live "/rta-management", Admin.Utilities.RtaManagement
      live "/bulk_monitor_operations", Admin.Utilities.BulkMonitorOperations
      live "/monitor-config", Admin.Utilities.MonitorConfig
      live "/change-monitor-tag", Admin.Utilities.ChangeMonitorTag
      live "/switch-test-monitor-state", Admin.Utilities.SwitchTestMonitorState
      live "/invalidate-events", Admin.Utilities.InvalidateEvents

      live "/playground", PlaygroundLive
    end
  end

  # Enables LiveDashboard, only for admin users in prod
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through :browser
    if Mix.env() == :prod do
      pipe_through :require_admin_user
    end
    live_dashboard "/live_dashboard",
      metrics: BackendWeb.Telemetry,
      ecto_repos: [Backend.Repo, Backend.TelemetryRepo],
      ecto_psql_extras_options: [
        null_indexes: [
          min_relation_size_mb: 10
        ]
      ]
  end

  scope "/api" do
    pipe_through :browser
    pipe_through :swagger_api

    get "/openapi", BackendWeb.API.RenderSpec, []
    get "/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
  end

  # Local checks and plugs around auth.

  # Missing: if it is already in the session, we're good. But this is typically
  # used with clients that will send the token on every request anyway, so
  # mostly just saving a DB query in case they do handle cookies. No big deal.
  def check_api_token(conn, _opts) do
    case check_metrist_api_token(conn) do
      nil ->
        check_account_api_token(conn)
      conn ->
        conn
    end
  end

  def check_internal_api_token(conn, _opts) do
    case check_metrist_api_token(conn) do
      nil ->
        conn
        |> send_resp(403, ~s({"error": "Forbidden"}))
        |> halt()
      conn ->
        conn
    end
  end

  def allow_iframe(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy", "frame-ancestors 'self' https://*.datadoghq.com/")
    |> delete_resp_header("x-frame-options")
  end

  def check_metrist_api_token(conn) do
    needed = Application.get_env(:backend_web, :api_token)
    seen = bearer_token(conn)
    if needed != seen do
      nil
    else
      conn
      |> put_session(:metrist_api_token, true)
      |> put_session(:account_api_token, false)
      |> put_session(:account_id, nil)
    end
  end

  def check_account_api_token(conn) do
    seen = bearer_token(conn)
    case Backend.Auth.APIToken.verify(seen) do
      nil ->
        conn
        |> send_resp(403, ~s({"error": "Forbidden"}))
        |> halt()
      account_id ->
        conn
        |> put_session(:metrist_api_token, false)
        |> put_session(:account_api_token, true)
        |> put_session(:account_id, account_id)
    end

  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [] -> ""
      [h | _] -> h
      |> String.replace("Bearer", "")
      |> String.trim()
    end
  end

  def require_new_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
    |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        redirect_to_login(conn)
      user ->
        case user.account_id do
          nil ->
            conn
          _ ->
            redirect_to_index(conn)
        end
    end
  end
  def require_unverified_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
    |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        redirect_to_login(conn)
      user ->
        case get_session(conn, :verified) do
          false ->
            # Check auth0 to see if they verified (session would still say they didn't)
            case Backend.UserFromAuth.is_verified(user) do
              true ->
                conn
                |> put_session(:verified, true)
                |> redirect_to_index()
              _ -> conn
            end
          _ -> redirect_to_index(conn)
        end
    end
  end

  def require_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
    |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        conn
        |> maybe_store_return_to()
        |> redirect_to_login()
      user ->
        case user.account_id do
          nil ->
            IO.inspect("#{__MODULE__} user is: #{inspect user}")
            conn
            |> BackendWeb.AuthController.login_with_no_account(user)
            |> halt()
          _ ->
            case get_session(conn, :verified) do
              false -> redirect_to_verify(conn)
              _ -> conn
            end
        end
    end
  end

  def require_no_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
    |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        conn
      _user ->
        redirect_to_index(conn)
    end
  end

  def require_admin_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
    |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        redirect_to_login(conn)
      user ->
        if user.is_metrist_admin do
          conn
        else
          redirect_to_index(conn)
        end
    end
  end

  def require_not_read_only_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
    |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        redirect_to_login(conn)
      user ->
        if not user.is_read_only do
          conn
        else
          redirect_to_index(conn)
        end
    end
  end

  def internal_only_plug(conn, _opts) do
    # It's not a lot of defense, but "internal" should not open up very
    # critical resources. ALB should have a rule blocking /internal and
    # this is just double checking that nothing slips through.
    case get_req_header(conn, "x-forwarded-for") do
      [] ->
        conn
      _ ->
        conn
        |> send_resp(403, "Forbidden")
        |> halt()
    end
  end


  def require_datadog_user_plug(conn, _opts) do
    {user, conn} = get_session(conn, :current_user)
      |> ensure_up_to_date_user(conn)

    case {user, conn} do
      {_any, %{request_path: "/dd-metrist/"}} ->
        conn
      {user, _}
        when user.account_id == nil
        when user == nil ->
        conn
        |> send_resp(403, "Forbidden")
        |> halt()
      _ ->
        conn
    end
  end

  # Separate plug for datadog to handle redirects
  def datadog_auth_plug(conn, _opts) do
    {user, conn}= get_session(conn, :current_user)
      |> ensure_up_to_date_user(conn)

    case user do
      nil ->
        conn
        |> maybe_store_return_to()
        |> redirect_to_login()
      %{account_id: nil} ->
        account_id = Domain.Id.new()

        cmd = %Domain.Account.Commands.Create{
          id: account_id,
          creating_user_id: user.id,
          name: nil,
          selected_monitors: [],
          selected_instances: []
        }
        Backend.App.dispatch_with_actor(Backend.Auth.Actor.datadog(user.id, account_id), cmd)

        conn
        |> put_session(:current_user, %{user | account_id: account_id})
      _ ->
        conn
    end
  end

  defp redirect_to_index(conn) do
    conn
    |> redirect(to: "/")
    |> halt()
  end

  defp redirect_to_login(conn) do
    conn
    |> redirect(to: "/login")
    |> halt()
  end

  defp redirect_to_verify(conn) do
    conn
    |> redirect(to: "/verify")
    |> halt()
  end

  defp maybe_get_body(conn, _opts) do
    case BackendWeb.Plugs.CachingBodyReader.read_body(conn, []) do
      # in all cases we return conn
      {_, _binary, conn} ->
        conn
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :auth_redirect, current_path(conn))
  end
  defp maybe_store_return_to(conn), do: conn

  defp validate_slack_signature(conn, _opts) do
    timestamp = Plug.Conn.get_req_header(conn, "x-slack-request-timestamp") |> Enum.at(0)
    signature = Plug.Conn.get_req_header(conn, "x-slack-signature") |> Enum.at(0)
    signing_secret = Application.get_env(:backend, :slack_signing_secret)
    body = BackendWeb.Plugs.CachingBodyReader.get_raw_body(conn)
    signed = :crypto.mac(:hmac, :sha256, signing_secret, "v0:#{timestamp}:#{body}")
    |> Base.encode16()
    |> String.downcase()
    if "v0=#{signed}" == signature do
      conn
    else
      conn
      |> put_status(500)
      |> text("Invalid signature")
      |> halt()
    end
  end

  defp ensure_up_to_date_user(user, conn) do
    {status, user} = BackendWeb.Helpers.get_up_to_date_user(user)
    case status do
      :ok -> {user, conn}
      :updated ->
        conn = put_session(conn, :current_user, user)
        {user, conn}
    end
  end
end
