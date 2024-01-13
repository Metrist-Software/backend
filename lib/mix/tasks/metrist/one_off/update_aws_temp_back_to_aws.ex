defmodule Mix.Tasks.Metrist.OneOff.UpdateAwsTempBackToAws do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-83 Moves all awstemp monitors back to aws"

  @opts [
    :dry_run,
    :env
  ]

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    "SHARED"
    |> Backend.Projections.get_monitor_configs()
    |> Enum.filter(fn monitor_config -> ("awstemp" in monitor_config.run_groups) end)
    |> Enum.map(fn monitor_config ->
        case Enum.find_index(monitor_config.run_groups, fn rg -> rg == "awstemp" end) do
          nil -> nil
          index -> %Domain.Monitor.Commands.SetRunGroups{
            id: "SHARED_" <> monitor_config.monitor_logical_name,
            config_id: monitor_config.id,
            run_groups: List.replace_at(monitor_config.run_groups, index, "aws")
          }
        end
      end)
    |> Enum.reject(&(is_nil((&1))))
    |> Helpers.send_commands(options.env, options.dry_run)
  end
end
