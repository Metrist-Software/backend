defmodule Mix.Tasks.Metrist.OneOff.MigrateRunGroupsFromRundll do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-373 Migrate run groups from RunDll to new format <platform>, <platform>:<env>, <platform>:<region> and finally <platform>:<env>/<region>"

  def run(args) do
    {opts, []} = Helpers.do_parse_args(
      args,
      [
        env: :string,
        dry_run: :boolean
      ],
      [
        e: :env,
        d: :dry_run
      ],
      [
        :env
      ]
    )


    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Task.run("app.config")

    # Mix.Tasks.Metrist.Helpers.start_repos()
    Logger.configure(level: :info)

    Application.ensure_all_started(:hackney)

    platform_map = %{
      "RunDLL" => "aws",
      "RunDLL-us-east-1" => "aws:us-east-1",
      "RunDLL-us-east-2" => "aws:us-east-2",
      "RunDLL-us-west-1" => "aws:us-west-1",
      "RunDLL-us-west-2" => "aws:us-west-2",
      "RunDLL-ca-central-1" => "aws:ca-central-1"
    }

    updated_configs =
      for account <- Backend.Projections.list_accounts() do
        Logger.info("Checking #{account.id}:#{account.name}")
        Backend.Projections.get_monitor_configs(account.id)
        |> Enum.map(fn cfg ->
          new_run_groups =
             case cfg.run_groups do
              nil -> nil
              run_groups ->
                run_groups
                |> Enum.map(fn rg ->
                  Map.get(platform_map, rg, rg)
                end)
             end
          { new_run_groups != cfg.run_groups, account.id, %{ cfg | run_groups: new_run_groups} }
        end)
      end
      |> List.flatten()
      |> Enum.reject(fn {changed, _account_id, _cfg} -> !changed end)

      run_group_commands =
        updated_configs
        |> Enum.map(fn {_changed, account_id, cfg} ->
          %Domain.Monitor.Commands.SetRunGroups{
            id: Backend.Projections.construct_monitor_root_aggregate_id(account_id, cfg.monitor_logical_name),
            config_id: cfg.id,
            run_groups: cfg.run_groups
          }
        end)

    case opts[:dry_run] do
      true ->
        run_group_commands
        |> IO.inspect(label: "Commands")
        Logger.info("#{length(run_group_commands)} commands would be sent")
      _ ->
        Logger.info("Sending #{length(run_group_commands)} commands")
        Mix.Tasks.Metrist.Helpers.send_commands(run_group_commands, opts[:env])
        Logger.info("Done sending #{length(run_group_commands)} commands")
    end
  end
end
