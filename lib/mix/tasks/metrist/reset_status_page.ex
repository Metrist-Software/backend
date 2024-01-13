defmodule Mix.Tasks.Metrist.ResetStatusPage do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @opts [
    :dry_run,
    :env,
    {:page, nil, :string, :mandatory, "Page to be reset"}
  ]
  @shortdoc "Reset a status page aggregate"
  @moduledoc """
  Resets a status page resetting aggregate state and removing the
  component projections.

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}

  ## Example

      MIX_ENV=prod mix metrist.reset_status_page -e dev1 --page fastly
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Helpers.start_repos(options.env)
    status_page = Backend.Projections.status_page_by_name(options.page)

    [
      %Domain.StatusPage.Commands.Reset{
        id: status_page.id
      }
    ]
    |> Helpers.send_commands(options.env, options.dry_run)
  end

end
