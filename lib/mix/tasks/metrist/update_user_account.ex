defmodule Mix.Tasks.Metrist.UpdateUserAccount do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    :account_id,
    {:user_id, nil, :string, :mandatory, "User id to update"}
  ]
  @shortdoc "Update a user's account"
  @moduledoc """
  #{@shortdoc}

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)

    Helpers.send_command(
      %Domain.User.Commands.Update{
        id: options.user_id,
        user_account_id: options.account_id
      },
      options.env, options.dry_run
    )
  end
end
