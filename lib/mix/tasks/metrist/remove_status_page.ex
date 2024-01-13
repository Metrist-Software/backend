defmodule Mix.Tasks.Metrist.RemoveStatusPage do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @opts [
    :dry_run,
    :env,
    {:page, nil, :string, :mandatory, "Page to be removed"}
  ]
  @shortdoc "Removes a Status Page from the system"
  @moduledoc """
  This will also remove projection data for the status page
  including subscriptions, component changes, components,
  and the status page itself

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}

  ## Example

      MIX_ENV=prod mix metrist.remove_status_page -e dev1 --page fastly
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    [
      %Domain.StatusPage.Commands.Remove{
        id: Backend.Projections.status_page_by_name(options.page).id
      }
    ]
    |> Helpers.send_commands(options.env, options.dry_run)

  end

end
