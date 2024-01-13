defmodule Mix.Tasks.Metrist.Helpers do
  @moduledoc """
  A bunch of helpers for our Mix tasks. Mostly having to do with setting up things we rely on like
  API keys, DB access, and a standard way to parse options.
  """

  @concurrency 50

  def start_repos(env) do
    configure(env)
    Mix.Task.run("app.config")
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:postgrex)
    {:ok, _} = Backend.Repo.start_link(pool_size: 10)
  end

  #
  def config_to_env(config) do
    # Some code expects environment variables, let's set them here
    System.put_env("SECRETS_NAMESPACE", config.secrets_namespace)
    System.put_env("ENVIRONMENT_TAG", config.environment_tag)
    System.put_env("AWS_REGION", config.region)
  end

  def config_from_env("local"),
    do: %{
      secrets_namespace: "/dev1/",
      environment_tag: "dev1",
      region: "us-east-1",
      app_url: "https://localhost:4443"
    }

  def config_from_env("local2") do
    Map.put(config_from_env("local"), :app_url, "https://localhost:4444")
  end

  def config_from_env("dev"),
    do: %{
      secrets_namespace: "/dev1/",
      environment_tag: "dev1",
      region: "us-east-1",
      app_url: "https://app-dev1.metrist.io"
    }

  def config_from_env("dev1"), do: config_from_env("dev")

  def config_from_env("prod"),
    do: %{
      secrets_namespace: "/prod/",
      environment_tag: "prod",
      region: "us-west-2",
      app_url: "https://app.metrist.io"
    }

  def config_from_env(other), do: raise "Unknown environment #{inspect other} specified"

  def configure(env) do
    config = config_from_env(env)
    config = Map.put(config, :env, env)
    config_to_env(config)
    config
  end

  def api_token(config) do
    %{"token" => token} =
      Backend.Application.get_json_secret(
        "canary-internal/api-token",
        config.secrets_namespace,
        config.region
      )

    token
  end

  def shared_api_token(config) do
    case config.env do
      "local" ->
        "fake-api-token-for-dev"
      _ ->
        %{"token" => token} =
          Backend.Application.get_json_secret(
            "canary-shared/api-token",
            config.secrets_namespace,
            config.region
          )
        token
    end
   end

  def send_command(cmd, env, dry_run \\ false)

  def send_command(cmd, env, dry_run) do
    send_commands([cmd], env, dry_run)
  end

  def send_commands(cmds, env, dry_run \\ false, force_sequential \\ false)

  def send_commands(cmds, _env, true, _force_sequential) do
    IO.inspect(cmds, label: "Dry run, commands that would be sent. Length #{length(cmds)}", pretty: true, limit: :infinity)
  end

  def send_commands(cmds, env, false, force_sequential) when is_list(cmds) do
    config = Mix.Tasks.Metrist.Helpers.config_from_env(env)
    token = api_token(config)

    do_send = fn item -> do_send_command(config, token, item) end
    perf_mode = length(cmds) > 25 && not force_sequential
    if perf_mode do
      # With a lot of commands, we're probably load testing and then this
      # becomes interesting info.
      IO.puts("Sending commands with concurrency #{@concurrency} to #{config.app_url}")
      Task.async_stream(cmds, do_send, max_concurrency: @concurrency, timeout: :infinity)
    else
      Enum.map(cmds, do_send)
    end
    |> Enum.to_list()
    IO.puts("Sent #{length(cmds)} commands to #{config.app_url}")
  end

  defp local_cert_options() do
    cert_dir = Path.join(File.cwd!(), "priv")

    [
      hackney: [
        ssl_options: [
          certfile: Path.join(cert_dir, "localhost+2.pem"),
          keyfile: Path.join(cert_dir, "localhost+2-key.pem")
        ]
      ]
    ]
  end

  def command_to_map(%kind{} = value) when is_struct(value) do
    # Only want to convert our command structs in the Domain.xxx namespace
    case Module.split(kind) do
      ["Domain", _agg, "Commands" | _] ->
        value
        |> Map.put("__struct__", String.replace("#{value.__struct__}", "Elixir.", ""))
        |> Map.delete(:__struct__)
        |> Enum.map(fn {k, v} -> {k, command_to_map(v)} end)
        |> Map.new()
      _ ->
        value
    end
  end
  def command_to_map(value) when is_list(value) do
    Enum.map(value, &command_to_map/1)
  end
  def command_to_map(value), do: value

  defp do_send_command(config, token, cmd) do
    # Trick Jason into thinking the command is not actually a struct. This
    # will make it send the type along so the other end can have its generic
    # translate_cmd code kick in.
    {:ok, json} =
      cmd
      |> command_to_map()
      |> Jason.encode()

    opts = if config.app_url =~ ~r"https://localhost:444[34]", do: local_cert_options(), else: []

    %{status_code: 200} =
      HTTPoison.post!(
        "#{config.app_url}/api/command",
        json,
        [{"content-type", "application/json"}, {"authorization", "Bearer #{token}"}],
        opts
      )
  end

  def parse_key_value_pair(kvp, opts \\ []) do
    options =
      Enum.into(opts, %{
        type: :string,
        default: nil,
        separator: "="
      })

    [key, value] =
      case String.split(kvp, options.separator, parts: 2) do
        [key, value] -> [key, value]
        [key] -> [key, options.default]
      end

    value =
      case options.type do
        :string ->
          value

        :integer when is_binary(value) ->
          {val, _} = Integer.parse(value)
          val

        :float when is_binary(value) ->
          {val, _} = Float.parse(value)
          val

        _ ->
          value
      end

    {key, value}
  end

  @standard_opts %{
    dry_run: {:dry_run, nil, :boolean, false, "Indicate that this is a dry run"},
    env: {:env, :e, :string, "local", "Environment to run against"},
    account_id: {:account_id, :a, :string, "SHARED", "The account id"},
    monitor_logical_name:
      {:monitor_logical_name, :m, :string, :mandatory, "Logical name of the monitor"},
    config_id: {:config_id, :c, :string, :mandatory, "Monitor configuration id"}
  }

  @doc """
  Parse arguments. `meta` is a list of arguments, which can either be a stand-alone atom that is a key into
  `@standard_opts`, or a tuple containing `{:long_opt, :short_opt, :type, default, description}`. If `default`
  is `:mandatory` then the option is seen as mandatory.

  Returns a map with long options as the keys and the default or command line values as the value. If the resulting
  options have both `account_id` and `monitor_logical_name` values, then the map will also contain a `monitor_id` entry
  which is the key for a monitor calculated from these two values.

  Not super friendly, in that it throws errors, because (for now) these Mix tasks are supposed to be used
  exclusively by engineers. Should be simple enough to make it nicer when we need that.
  """
  def parse_args(meta, args) do
    meta = replace_standard_opts(meta)

    meta_by_key =
      meta
      |> Enum.map(fn meta = {key, _, _, _, _} -> {key, meta} end)
      |> Map.new()

    strict = build_definitions(meta)
    aliases = build_aliases(meta)

    {opts, []} =
      OptionParser.parse!(
        args,
        strict: strict,
        aliases: aliases
      )

    defaults = build_defaults(meta)

    opts =
      Enum.reduce(opts, defaults, fn {k, v}, acc ->
        case meta_by_key[k] do
          {_, _, :keep, _, _} ->
            Map.update(acc, k, [v], fn l ->
              if l == :mandatory, do: [v], else: l ++ [v]
            end)

          _ ->
            Map.put(acc, k, v)
        end
      end)

    required = build_required(meta)
    missing = Enum.filter(required, fn tag -> opts[tag] == :mandatory end)

    if length(missing) > 0 do
      missing_dashed = Enum.map(missing, fn a -> String.replace("#{a}", "_", "-") end)

      raise "\n\nMissing required option(s): #{inspect(missing_dashed)}\n\nUse `mix help <taskname>` to see what options are expected\n"
    end

    opts
    |> maybe_enrich_with_monitor_id()
  end

  @doc """
  Generate a doc string from the arguments. This saves typing.
  """
  def gen_command_line_docs(meta) do
    docstrings =
      meta
      |> replace_standard_opts()
      |> Enum.map(fn {long, short, type, default, description} ->
        long = Atom.to_string(long)
        long_dashed = String.replace(long, "_", "-")

        arg =
          case short do
            nil -> "--#{long_dashed}"
            short -> "--#{long_dashed}/-#{short}"
          end

        name =
          case type do
            :boolean ->
              ""

            :count ->
              ""

            _ ->
              "<#{long}>"
          end

        default =
          case default do
            nil -> ""
            :mandatory -> "(required)"
            default -> "(default #{inspect(default)})"
          end

        "* `#{arg} #{name}` - #{description} #{default}"
      end)

    """
    ## Options:

    #{Enum.join(docstrings, "\n")}
    """
  end

  @doc """
  Extra documentation to include in case this requires the database.
  """
  def mix_env_notice() do
    """
    ## Running locally or against prod, dev1

    For the `--env/-e` option, if you run this command against local, you can just invoke `mix ...`. However,
    for our deployed environments, like `prod` and `dev`, you need to have `MIX_ENV` set to `prod` - this
    so that the production configuration comes in to play which fetches database secrets from AWS Secrets
    Manager, etcetera. The simplest way to do this is to type

        MIX_ENV=prod mix ...

    in these cases.
    """
  end

  defp replace_standard_opts(opts) do
    opts
    |> Enum.map(fn opt ->
      case Map.get(@standard_opts, opt) do
        nil -> opt
        value -> value
      end
    end)
   end

  defp build_definitions(meta) do
    meta
    |> Enum.map(fn {long, _, type, _, _} -> {long, type} end)
  end

  defp build_aliases(meta) do
    meta
    |> Enum.map(fn {long, short, _, _, _} -> {short, long} end)
    |> Enum.filter(fn {short, _} -> not is_nil(short) end)
  end

  defp build_defaults(meta) do
    meta
    |> Enum.map(fn {long, _, _, default, _} -> {long, default} end)
    |> Map.new()
  end

  defp build_required(meta) do
    meta
    |> Enum.filter(fn {_, _, _, default, _} -> default == :mandatory end)
    |> Enum.map(fn {long, _, _, _, _} -> long end)
  end

  defp maybe_enrich_with_monitor_id(
         %{account_id: account_id, monitor_logical_name: monitor_logical_name} = opts
       )
       when not is_nil(account_id) and not is_nil(monitor_logical_name) do
    Map.put(
      opts,
      :monitor_id,
      Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor_logical_name)
    )
  end
  defp maybe_enrich_with_monitor_id(opts), do: opts

  @doc """
  This function should only be used for special cases, basically bootstrapping new stuff where we
  dont have a running backend available. The current use case is creating the shared account.
  """
  def bootstrap_start_everything(env) do
    start_repos(env)
    Application.ensure_all_started(:commanded)
    Application.ensure_all_started(:commanded_eventstore_adapter)
    {:ok, _} = Backend.App.start_link()
  end

  # Dummy implementations to keep the compiler happy for old one_off scripts.
  def do_parse_args(_, _, _, _), do: {[], []}
  def env_from_opts(_), do: "local"
end
