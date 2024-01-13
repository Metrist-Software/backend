defmodule Mix.Tasks.Metrist.OneOff.FixSecretsNamespaceInConfigs do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-323 cleanup env by removing secrets namespace"

  @opts [
    :dry_run,
    :env
  ]

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    "SHARED"
    |> Backend.Projections.get_monitor_configs()
    |> Enum.map(fn monitor_config ->
      decoded = Domain.CryptUtils.decrypt_field(monitor_config.extra_config)
      %{monitor_config | extra_config: decoded}
    end)
    |> Enum.map(fn monitor_config ->
      case monitor_config.extra_config do
        nil ->
          []

        ec ->
          Enum.map(ec, fn {k, v} -> {monitor_config, k, v} end)
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn {_mv, _k, v} ->
      is_binary(v) and String.contains?(v, "SECRETS_NAMESPACE")
    end)
    |> Enum.map(fn {mc, k, v} ->
      %Domain.Monitor.Commands.SetExtraConfig{
        id: "SHARED_" <> mc.monitor_logical_name,
        config_id: mc.id,
        key: k,
        value: String.replace(v, "${SECRETS_NAMESPACE}", "/${ENVIRONMENT_TAG}/")
      }
    end)
    |> Helpers.send_commands(options.env, options.dry_run)
  end
end
