defmodule Mix.Tasks.Metrist.CreateMonitor do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Sets up a monitor with configuration"

  @opts [
    :dry_run,
    :env,
    :account_id,
    :monitor_logical_name,
    {:display_name, nil, :string, :mandatory, "Display name for monitor"},
    {:monitor_interval, nil, :integer, 120, "Interval in seconds to run monitor"},
    {:analyzer_interval, nil, :integer, 60, "Interval in seconds to run analyzer"},
    {:run_group, nil, :string, "aws", "Run group(s) to place the monitor in"},
    {:tag, nil, :string, nil, "Tags to tag the monitor with"},
    {:run_type, nil, :string, "dll", "How to run the monitor"},
    {:run_name, nil, :string, nil, "The name for the thing to run (depends on run_type, default is logical_name)"},
    {:config_only, nil, :boolean, false, "If set, the monitor is expected to exist and only config is updated"}
  ]

  @moduledoc """
  This Mix tasks adds a new monitor to the given account and sets up the required
  configurations for it.

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    options = Map.update(options, :run_name, options.monitor_logical_name, fn v ->
      if not is_nil(v), do: v, else: options.monitor_logical_name end)

    run_type = String.to_atom(Map.get(options, :run_type, "dll"))

    config_id = Domain.Id.new()

    [
      if not Map.get(options, :config_only, false) do
        [
          %Domain.Account.Commands.AddMonitor{
            id: options.account_id,
            logical_name: options.monitor_logical_name,
            name: options.display_name,
            check_configs: [],
            default_degraded_threshold: 5.0,
            instances: [],
          },
          %Domain.Monitor.Commands.Create{
            id: options.monitor_id,
            monitor_logical_name: options.monitor_logical_name,
            name: options.display_name,
            account_id: options.account_id
          },
          if Map.has_key?(options, :tag) do
            %Domain.Monitor.Commands.AddTag{
              id: options.monitor_id,
              tag: options.tag
            }
          else
            []
          end
        ]
      end,
      %Domain.Monitor.Commands.AddConfig{
        id: options.monitor_id,
        config_id: config_id,
        monitor_logical_name: options.monitor_logical_name,
        run_groups: [options.run_group],
        interval_secs: options.monitor_interval,
        run_spec: %Domain.Monitor.Commands.RunSpec{
          run_type: run_type,
          name: options.run_name
        },
        steps: []
      },
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Helpers.send_commands(options.env, options.dry_run)

    IO.puts("\nCreated monitor #{options.account_id}_#{options.monitor_logical_name}. Use config_id #{config_id} for set_extra_config\n\n")
  end
end
