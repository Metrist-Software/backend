defmodule Mix.Tasks.Metrist.InstallMonitor do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    :account_id,
    {:config_file, :f, :string, :mandatory, "The configuration source file for the monitor"},
    {:monitor_interval, nil, :integer, 120, "The interval in seconds between monitor runs"},
    {:analyzer_interval, nil, :integer, 60, "The interval in seconds between analyzer runs"},
    {:timeout_secs, nil, :integer, 900, "The default value for check timeouts"},
    {:run_group, nil, :string, "DISABLED", "The run group for the monitor"},
  ]

  @shortdoc "Installs a monitor from a JSON description"
  @moduledoc """
  This Mix task takes an environment and a monitor description file and creates the monitor
  configuration, including run steps, timeouts, and extra config from it.

  The monitor description is validated using JSON Schema.

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    monitor_config = validate_monitor_file(options.config_file)

    # Now that everything passes it's time to set stuff up

    run_spec = monitor_config["run_spec"]

    # To do: if we can somehow deterministically fetch the monitor_config id, we can
    # make this all idempotent. Maybe pass it in from the command line?
    config_id = Domain.Id.new()

    monitor_id =
      Backend.Projections.construct_monitor_root_aggregate_id(
        options.account_id,
        monitor_config["name"]
      )

    [
      %Domain.Account.Commands.AddMonitor{
        id: options.account_id,
        logical_name: monitor_config["name"],
        name: monitor_config["description"],
        check_configs: [],
        default_degraded_threshold: 5.0,
        instances: []
      },
      %Domain.Monitor.Commands.Create{
        id: monitor_id,
        monitor_logical_name: monitor_config["name"],
        name: monitor_config["description"],
        account_id: options.account_id
      },
      %Domain.Monitor.Commands.AddTag{
        id: monitor_id,
        tag: monitor_config["tag"]
      },
      %Domain.Monitor.Commands.AddConfig{
        id: monitor_id,
        config_id: config_id,
        monitor_logical_name: monitor_config["name"],
        run_groups: [options.run_group],
        interval_secs: monitor_config["interval_secs"] || options.monitor_interval,
        run_spec: %Domain.Monitor.Commands.RunSpec{
          run_type: String.to_atom(run_spec["type"]),
          name:
            if(Map.has_key?(run_spec, "name"), do: run_spec["name"], else: monitor_config["name"])
        },
        steps:
          Enum.map(monitor_config["steps"], fn step ->
            %Domain.Monitor.Commands.Step{
              check_logical_name: step["name"],
              timeout_secs: options.timeout_secs
            }
          end),
        extra_config: monitor_config["extra_config"]
      }
    ]
    |> Mix.Tasks.Metrist.Helpers.send_commands(options.env, options.dry_run)

    IO.puts("""

    Created monitor #{options.account_id}_#{monitor_config["name"]} in #{options.env}.

    This monitor is currently disabled through its run group. To get it scheduled in our
    default run group, execute (after ensuring that the monitor has been packaged):

        mix metrist.set_run_group -e #{options.env} -a #{options.account_id} -m #{monitor_config["name"]} -c #{config_id} --run-group aws

    Use config_id #{config_id} for future changes.

    """)
  end

  # Validation stuff. Note that this is meant for interactive use
  # by developers, so just tossing errors is fine and keeps things simple.

  # JSON Schema is one of these "meh" ideas that is probably just useful enough for this purpose to
  # use it as a quick validator :)

  @schema %{
    "type" => "object",
    "properties" => %{
      "name" => %{
        "type" => "string"
      },
      "description" => %{
        "type" => "string"
      },
      "tag" => %{
        "type" => "string"
      },
      "run_spec" => %{
        "type" => "object",
        "properties" => %{
          "type" => %{
            "type" => "string"
          },
          "name" => %{
            "type" => "string"
          }
        },
        "required" => ["type"]
      },
      "steps" => %{
        "type" => "array",
        "items" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{
              "type" => "string"
            },
            "description" => %{
              "type" => "string"
            },
            "timeout" => %{
              "type" => "number",
              "minimum" => 1
            }
          },
          "required" => ["name"]
        },
        "minItems" => 1,
        "uniqueItems" => true
      },
      "extra_config" => %{
        "type" => "object"
      }
    },
    "required" => ["name", "description", "tag", "run_spec", "steps"]
  }

  @resolved_schema ExJsonSchema.Schema.resolve(@schema)

  def validate_monitor_file(filename) do
    {:ok, contents} = File.read(filename)
    validate_monitor(contents)
  end

  def validate_monitor(json) do
    {:ok, parsed} = Jason.decode(json)
    :ok = ExJsonSchema.Validator.validate(@resolved_schema, parsed)
    parsed
  end
end
