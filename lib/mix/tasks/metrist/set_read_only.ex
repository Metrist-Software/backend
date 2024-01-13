defmodule Mix.Tasks.Metrist.SetReadOnly do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    {:email_or_id, nil, :string, :mandatory, "User's email or id"},
    {:is_read_only, nil, :boolean, :mandatory, "User's new read-only state"}
  ]

  @shortdoc "Sets a user's read-only state"

  @moduledoc """
  This Mix tasks sets the read-only state for a user, so that that user has (or ceases to have)
  permissions for certain tasks in the frontend. You can pass an email address or an id.

    MIX_ENV=prod mix metrist.set_read_only --env dev1  --email-or-id tina@metrist.io --is-read-only=true

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)

    email_or_id = opts.email_or_id
    user =
      case Backend.Projections.get_user(email_or_id) do
        nil -> case Backend.Projections.user_by_email(email_or_id) do
          nil ->
            raise "Could not find user #{email_or_id} by email or id"

          user ->
            user
        end

        user ->
          user
      end

    Helpers.send_command(
      %Domain.User.Commands.SetReadOnly{id: user.id, is_read_only: opts.is_read_only},
      opts.env, opts.dry_run)

    IO.puts("\nSet user #{user.id} read-only to #{opts.is_read_only}")
  end
end
