defmodule Mix.Tasks.Metrist.OneOff.MigrateMonitorConfigs do
  use Mix.Task
  require Logger

  @shortdoc "Migrate monitor configurations from code to db"
  # No moduledoc, one-off commands don't need to appear in `mix help`

  def run(args) do
    if Mix.env == :prod && System.get_env("ENVIRONMENT_TAG") == nil do
      raise "This mix task accesses the database directly, set MIX_ENV=prod and ENVIRONMENT_TAG accordingly"
    end
    Mix.Task.run("app.config")
    #Mix.Tasks.Metrist.Helpers.start_commanded()
    # Mix.Tasks.Metrist.Helpers.start_repos()

    {opts, []} =
      OptionParser.parse!(
        args,
        strict: [
          account_id: :string
        ],
        aliases: [
          a: :account_id
        ]
      )

    missing =
      [:account_id]
      |> Enum.filter(fn opt -> is_nil(opts[opt]) end)
    if length(missing) > 0, do: raise("Missing required option(s): #{inspect(missing)}")
    IO.inspect(opts, label: "Parsed options")

    env = System.get_env("ENVIRONMENT_TAG")

    config = Mix.Tasks.Metrist.Helpers.config_from_env(env)
    IO.inspect(config, label: "Parsed config")

    %{"token" => token} =
      Backend.Application.get_json_secret(
        "canary-internal/api-token",
        config.secrets_namespace,
        config.region
      )

    # For the account, pull down all monitor_configs, then fetch the templates and set the run_config and steps
    # fields through the new commands.
    account_id = opts[:account_id]
    for mc <- Backend.Projections.get_monitor_configs(account_id) do
      Logger.info("Migrating #{mc.monitor_logical_name}")
      monitor_id = Backend.Projections.construct_monitor_root_aggregate_id(account_id, mc.monitor_logical_name)

      template =
        case {mc.monitor_logical_name, mc.check_logical_name} do
          {"zoom", "JoinCall"} ->
            %{run_spec: %Domain.Monitor.Commands.RunSpec{run_type: :exe, name: "zoomclient"},
              steps: [%Domain.Monitor.Commands.Step{check_logical_name: "JoinCall", timeout_secs: 900.0}]}

          _ ->
            Backend.Projections.Dbpa.MonitorConfig.template(mc.monitor_logical_name, account_id)
        end

      dispatch(env, config, token, %Domain.Monitor.Commands.SetRunSpec{
        id: monitor_id,
        config_id: mc.id,
        run_spec: template.run_spec
      })
      dispatch(env, config, token, %Domain.Monitor.Commands.SetSteps{
        id: monitor_id,
        config_id: mc.id,
        steps: template.steps
      })
    end
  end

  defp dispatch(env, _config, _token, cmd) do
    Logger.info(" - #{inspect cmd}")
    case env do
      "local" -> Backend.App.dispatch_with_actor(Backend.Auth.Actor.metrist_mix(), cmd)
      _ -> :ok # Mix.Tasks.Metrist.Helpers.send_command(config, token, cmd)
    end

  end
end
