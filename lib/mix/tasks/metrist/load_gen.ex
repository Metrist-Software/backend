defmodule Mix.Tasks.Metrist.LoadGen do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :env,
    {:count, nil, :integer, nil, "The number of commands to send"}
  ]

  @mons [
    # Basically the standard set on local dev, should be available everywhere.
    "testsignal",
    ]

  # Not currently being used
  # @other_mons [
  #   "azuredevops",
  #   "authzero",
  #   "avalara",
  #   "awsecs",
  #   "awsiam",
  #   "awslambda",
  #   "awsrds",
  #   "azuread",
  #   "azureaks",
  #   "braintree",
  #   "circleci",
  #   "cloudflare",
  #   "cognito",
  #   "datadog",
  #   "easypost",
  #   "ec2"
  # ]

  @checks %{
    "dev" => %{
      "testsignal" => ["Zero", "Normal", "Possion"],
      "azuredevops" => ["CloneRepo", "PushCode"],
      "authzero" => ["GetAccessToken", "GetBranding"],
      "avalara" => ["Ping"],
      "awsecs" => ["CreateService", "PingService", "DestroyService"],
      "awsiam" => ["CreateUser", "CreateGroup"],
      "awslambda" => ["TriggerLambdaAndWaitForResponse"],
      "awsrds" => ["CreateInstance", "PingInstance", "DestroyInstance"],
      "azuread" => ["Authenticate", "WriteUser", "ReadUser"],
      "azureaks" => ["CreateCluster", "CreateDeployment"],
      "braintree" => ["SubmitSandboxTransaction"],
      "circleci" => ["StartPipeline", "RunMonitorDockerWorkflow"],
      "cloudflare" => ["Ping", "DNSLookup", "CDN"],
      "cognito" => ["CreateUser", "DeleteUser"],
      "datadog" => ["SubmitEvent", "GetEvent"],
      "easypost" => ["GetAddressesTest"],
      "ec2" => ["RunInstance", "TerminateInstance"]
    },
    "local" => %{
      # All the fake monitors have a "zero" check in local
      "testsignal" => ["Zero"],
      "azuredevops" => ["Zero"],
      "authzero" => ["Zero"],
      "avalara" => ["Zero"],
      "awsecs" => ["Zero"],
      "awsiam" => ["Zero"],
      "awslambda" => ["Zero"],
      "awsrds" => ["Zero"],
      "azuread" => ["Zero"],
      "azureaks" => ["Zero"],
      "braintree" => ["Zero"],
      "circleci" => ["Zero"],
      "cloudflare" => ["Zero"],
      "cognito" => ["Zero"],
      "datadog" => ["Zero"],
      "easypost" => ["Zero"],
      "ec2" => ["Zero"]
    }
  }

  @shortdoc "Run load generation"
  @moduledoc """
  #{@shortdoc}

  This module emits a lot of telemetry to the targeted system. It can be used to assess performance
  when a customer instance sends a lot of data, or (later on) to see whether things like load shedding/throttling
  work.

  #{Helpers.gen_command_line_docs(@opts)}

  ## Example:

      mix metrist.load_gen -e local --count 1000
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    {:ok, instance} = :net.gethostname()
    instance = List.to_string(instance)
    instances = Enum.map(1..10, &("lg#{&1}-#{instance}"))
    checks = Map.get(@checks, options.env)

    telemetry_entries = 1..options.count
    |> Enum.map(fn _ ->
      mon = Enum.random(@mons)
      check = Enum.random(Map.get(checks, mon))
      instance = Enum.random(instances)

      msg = %{
        monitor_logical_name: mon,
        instance_name: instance,
        check_logical_name: check,
        value: Enum.random(3_000..5_000) / 1,
        metadata: %{"metrist.source" => "monitor"}
      }
      Jason.encode!(msg)
    end)

    # Prep stuff so that the post methods can just fly.
    config = Helpers.configure(options.env)
    api_token = Helpers.shared_api_token(config)
    Application.put_env(:backend, :config, config)
    Application.put_env(:backend, :api_token, api_token)

    do_send = fn msg ->
      __MODULE__.MetristAPI.post("agent/telemetry", msg, [{"Content-Type", "application/json"}])
    end

    Application.ensure_all_started(:httpoison)

    # To do: make concurrency configurable.
    Task.async_stream(telemetry_entries, do_send, max_concurrency: 50, timeout: :timer.hours(1))
    |> Stream.run() # Wait until done.

  end

  # Shamelessly stolen from Orchestrator, probably more than we need but using the
  # same method as Orch will help us keep things as real as possible.
  defmodule MetristAPI do
    use HTTPoison.Base

    def config(), do: Application.get_env(:backend, :config)

    @impl true
    def process_url(url) do
      host = config().app_url
      "#{host}/api/#{url}"
    end

    @impl true
    def process_request_options(opts) do
      # This is mainly so we can run against the "fake" CA that a local backend will use. Another option
      # is to actually install the CA system-wide but that comes with its own set of risks.
      opts = case config().env do
               "local" ->
                 Keyword.put_new(opts, :ssl, [verify: :verify_none])
               _ ->
                 opts
             end

      # This works for the most part as long as the appropriate HTTP status codes are returned
      # See https://hexdocs.pm/httpoison/HTTPoison.MaybeRedirect.html for details
      Keyword.put_new(opts, :follow_redirect, true)
    end

    @impl true
    def process_request_headers(headers) do
      if Enum.any?(headers, fn {header, _value} -> header == "Authorization" end) do
        headers
      else
        api_token = Application.get_env(:backend, :api_token)
        [{"Authorization", "Bearer #{api_token}"} | headers]
      end
    end
  end
end
