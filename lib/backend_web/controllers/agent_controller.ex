defmodule BackendWeb.AgentController do
  use BackendWeb, :controller

  require Logger

  @moduledoc """
  Handle Metrist Agent interactions, like pulling configuration data and
  sending telemetry/errors
  """

  # Mostly for documentation purposes, the data types we expect to interact with. A bit
  # more concise than GraphQL and potentially easily shareable with the client code. This
  # is an experiment, if it doesn't pan out GQL or JSON Schema is a fine option too.
  use TypedStruct

  typedstruct module: RunConfig do
    @moduledoc """
    Format for Run Configuration returned from `BackendWeb.AgentController.run_config/2`.
    """

    typedstruct module: Monitor do
      @derive Jason.Encoder
      field :id, String.t()
      field :monitor_logical_name, String.t()
      field :interval_secs, integer
      field :run_spec, Domain.Monitor.Commands.RunSpec.t()
      field :extra_config, %{String.t() => String.t()}
      field :last_run_time, NaiveDateTime.t()
      field :steps, [Domain.Monitor.Commands.Step.t()]
    end

    @derive Jason.Encoder
    field :monitors, [Monitor]
  end

  typedstruct module: Telemetry, enforce: true do
    @moduledoc """
    Format for telemetry posted to `BackendWeb.AgentController.telemetry/2`. This is pretty
    much the same as the AddTelemetry command.
    """
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :check_logical_name, String.t()
    field :value, float
    field :metadata, Domain.Monitor.Commands.metadata()
  end

  typedstruct module: Error, enforce: true do
    @moduledoc """
    Format for error posted to `BackendWeb.AgentController.error/2`. Pretty much the same
    as the AddError command.
    """
    field :monitor_logical_name, String.t()
    field :instance_name, String.t()
    field :check_logical_name, String.t()
    field :message, String.t()
    field :time, NaiveDateTime.t()
    field :metadata, Domain.Monitor.Commands.metadata()
    field :blocked_steps, [String.t()]
  end

  typedstruct module: HostTelemetry, enforce: true do
    @moduledoc """
    Format for host telemetry we receive from Agent instances.
    """
    field :instance, String.t()
    field :cpu, integer
    field :mem, integer
    field :disk, integer
  end

  @doc """
  Return the run configuration for the indicated instance id. Note that at the moment, this is a sort of
  best effort thing because we don't have an explicit configuration. We use monitor configurations to figure
  out what monitors should be run (everywhere); some sort of "I want this running here and that running there"
  functionality still needs to be built.
  """
  def run_config(conn, parms = %{"instance" => instance}) do
    account_id = get_session(conn, :account_id)
    instance = translate_instance(instance)
    peer =
      case get_req_header(conn, "x-forwarded-for") do
        [] -> :inet.ntoa(conn.remote_ip)
        [hdr | _] -> hdr
      end

    Logger.info("Config request for acct:#{account_id} instance:#{instance} ua:#{get_req_header(conn, "user-agent")} peer:#{peer}")

    # Monitor configs are where monitors are configured
    run_groups = Map.get(parms, "rg", [])
    cfgs = Backend.Projections.get_monitor_configs(account_id, run_groups)
    # Monitor instances are where monitors report back
    instances = Backend.Projections.get_monitor_instances_for_instance(account_id, instance)

    # configs either have a nil CheckLogicalName which indicates we want to run all checks, or the single
    # check to run. Convert the MonitorConfig into the RunConfig.Monitor structure above.
    run_config = build_run_config(cfgs, instances)
    json(conn, run_config)
  end

  # We have 1 million microseconds worth of processing time each second for each
  # monitor. Note that if a monitor starts to back up, this will immediately be reflected
  # in our timings which will start eating large amounts of tokens, but without load this
  # should allow us to go full speed (as we are likely lowballing the number of tokens we )
  @ratelimit_bucket_ms 1_000
  @ratelimit_count 1_000_000

  @doc """
  Process the POSTed telemetry data
  """
  def telemetry(conn, _params) do
    body = conn.body_params
    account_id = get_session(conn, :account_id)
    monitor_logical_name = body["monitor_logical_name"]
    monitor_id = Backend.CommandTranslator.translate_id(account_id, monitor_logical_name)

    command = %Domain.Monitor.Commands.AddTelemetry{
      id: monitor_id,
      account_id: account_id,
      monitor_logical_name: monitor_logical_name,
      instance_name: translate_instance(body["instance_name"]),
      check_logical_name: body["check_logical_name"],
      value: body["value"],
      metadata: body["metadata"] || %{},
      is_private: account_id != "SHARED",
      report_time: NaiveDateTime.utc_now()
    }

    case Hammer.check_rate("add_telemetry:#{monitor_id}", @ratelimit_bucket_ms, @ratelimit_count) do
      {:allow, _count} ->
        {time_us, dispatch_result} = :timer.tc(fn ->
          do_add_telemetry(conn, command)
        end)

        if dispatch_result == {:error, :aggregate_execution_timeout} do
          # We received a dispatch timeout, immediately deplete the rate limit quota
          Hammer.check_rate_inc("add_telemetry:#{monitor_id}", @ratelimit_bucket_ms, @ratelimit_count, @ratelimit_count)
        else
          # Use up the number of microseconds we required. Minus one for the initial check.
          Hammer.check_rate_inc("add_telemetry:#{monitor_id}", @ratelimit_bucket_ms, @ratelimit_count, time_us - 1)
        end

        respond(dispatch_result, conn)
      {:deny, _limit} ->
        Logger.info("Rate limit active on #{monitor_id}!")
        conn
        |> resp(429, "Too Many Requests")
      {:error, reason} ->
        Logger.error("Got Hammer error, allowing request through. Reason: #{reason}")

        do_add_telemetry(conn, command)
        |> respond(conn)
    end
    |> put_rate_limit_headers(Hammer.inspect_bucket("add_telemetry:#{monitor_id}", @ratelimit_bucket_ms, @ratelimit_count))
  end

  defp do_add_telemetry(conn, command) do
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(conn, command)
  end

  defp put_rate_limit_headers(conn, {:ok, bucket_data}) do
    {count, count_remaining, ms_to_next_bucket, _, _} = bucket_data

    reset_time_sec = ceil(ms_to_next_bucket / 1_000)

    conn
    |> put_resp_header("x-ratelimit-limit", to_string(count))
    |> put_resp_header("x-ratelimit-remaining", to_string(count_remaining))
    |> put_resp_header("x-ratelimit-reset", to_string(reset_time_sec))
  end

  @doc """
  Process the POSTed error data
  """
  def error(conn, _params) do
    body = conn.body_params
    account_id = get_session(conn, :account_id)
    monitor_logical_name = body["monitor_logical_name"]
    monitor_id = Backend.CommandTranslator.translate_id(account_id, monitor_logical_name)
    command = %Domain.Monitor.Commands.AddError{
      id: monitor_id,
      account_id: account_id,
      monitor_logical_name: monitor_logical_name,
      error_id: Domain.Id.new(),
      instance_name: translate_instance(body["instance_name"]),
      check_logical_name: body["check_logical_name"],
      message: body["message"],
      report_time: NaiveDateTime.from_iso8601!(body["time"]),
      metadata: body["metadata"] || %{},
      blocked_steps: body["blocked_steps"],
      is_private: account_id != "SHARED"
    }
    Backend.MonitorErrorTelemetry.register_error(command)
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(conn, command)
    |> respond(conn)
  end

  @doc """
  Process the POSTed host telemetry data. This goes straight into the telemetry library so something
  else can sort out what will happen with it.
  """
  def host_telemetry(conn, _params) do
    body = conn.body_params
    Backend.AgentMonitor.heartbeat(body["instance"])
    Backend.AgentHostTelemetry.execute(
      %{cpu: body["cpu"], mem: body["mem"], disk: body["disk"],
        max_cpu: maybe_get_max_cpu(body), instance: body["instance"]})

    respond(:ok, conn)
  end

  def monitor_alert(conn, _params) do
    body = conn.body_params

    token = Application.get_env(:backend, :slack_api_token)
    channel = "#oncall"
    blocks = []

    description = if body["monitor_state"] == "ok" do
      "has started running again."
    else
      "has not been running since #{body["last_update_time"]}."
    end

    text = "Monitor #{body["monitor_id"]} (config `#{body["config_id"]}`) from instance `#{body["instance_id"]}` #{description}"

    if Application.get_env(:backend, :enable_monitor_running_alerts) do
      Backend.Integrations.Slack.post_message(token, channel, text, blocks)
    end

    resp(conn, 200, text)
  end

  # Helpers

  def respond(commanded_status, conn) do
    case commanded_status do
      :ok ->
        resp(conn, 202, "Accepted")
      {:error, :aggregate_execution_timeout} ->
        resp(conn, 202, "Accepted") # The dispatch call timed out, but still most likely went through and shouldn't be retried
      {:error, _error} ->
        resp(conn, 500, "Internal Server Error")
    end
  end

  def build_run_config(configs, instances) do
    monitors =
      Enum.map(configs, fn config ->
        %RunConfig.Monitor{
          id: config.id,
          monitor_logical_name: config.monitor_logical_name,
          interval_secs: config.interval_secs,
          last_run_time: last_instance_report(config.monitor_logical_name, instances),
          extra_config: decrypt(config.extra_config),
          run_spec: config.run_spec,
          steps: config.steps
        }
      end)

    %RunConfig{monitors: monitors}
  end

  defp last_instance_report(monitor_logical_name, instances) do
    case Enum.find(instances, fn instance ->
          # TODO we probably should check the latest/earliest time a step was run instead.
          # However, multiple runs or a skipped run during an upgrade is not critical.
          instance.monitor_logical_name == monitor_logical_name
         end) do
      nil -> nil
      instance -> instance.last_report
    end
  end

  defp decrypt(nil), do: nil
  defp decrypt(map) do
    map
    |> Enum.map(fn {k, v} -> {k, Domain.CryptUtils.decrypt_field(v)} end)
    |> Map.new()
  end

  defp maybe_get_max_cpu(%{ "max_cpu" => max_cpu}), do: max_cpu
  defp maybe_get_max_cpu(_), do: 0

  def translate_instance("aws:" <> aws_region) do
    aws_region
  end
  def translate_instance(instance), do: instance
end
