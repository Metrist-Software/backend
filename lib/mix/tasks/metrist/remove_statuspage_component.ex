defmodule Mix.Tasks.Metrist.RemoveStatuspageComponent do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    {:id, nil, :string, :mandatory, "ID of the Status Page"},
    {:name, nil, :string, :mandatory, "Name of the component to remove"},

  ]

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    cmd = %Domain.StatusPage.Commands.RemoveComponent{
      id: options.id,
      component_name: options.name
    }

    Helpers.send_command(cmd, options.env, options.dry_run)
  end
end
