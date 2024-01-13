defmodule Mix.Tasks.Metrist.RemoveSlackWorkspace do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    :account_id,
    {:workspace_id, nil, :string, :mandatory, "Slack workspace ID"}
  ]
  @shortdoc "Removes a Slack Workspace from an account"
  @moduledoc """
  This is mostly for out of sync workspaces, i.e. any that were manually removed
  from slack without the change being applied to backend's data.

  #{Helpers.gen_command_line_docs(@opts)}

  ## Example

      mix metrist.remove_slack_workspace -e dev1 -a account_id --workspace-id workspace_id

  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.send_command(
      %Domain.Account.Commands.RemoveSlackWorkspace{
        id: options.account_id,
        team_id: options.workspace_id
      },
      options.env, options.dry_run)
  end
end
