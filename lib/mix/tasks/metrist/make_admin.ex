defmodule Mix.Tasks.Metrist.MakeAdmin do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :dry_run,
    :env,
    {:email_or_id, nil, :string, :mandatory, "User's email or id"}
  ]

  @shortdoc "Makes a user an admin user"

  @moduledoc """
  This Mix tasks sets the admin flag for a user, so that that user can access all
  functions (including Metrist internal ones). You can pass an email address or an
  id.

    MIX_ENV=prod mix metrist.make_admin --env dev1  --email-or-id daven@metrist.io

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)

    email_or_id = opts.email_or_id
    user =
      case Backend.Projections.get_user(email_or_id) do
        nil ->
          case Backend.Projections.user_by_email(email_or_id) do
            nil ->
              raise "Could not find user #{email_or_id} by email or id"

            user ->
              user
          end

        user ->
          user
      end


    Helpers.send_command(
      %Domain.User.Commands.MakeAdmin{id: user.id},
      opts.env, opts.dry_run)

    IO.puts("\nSet the admin flag on user #{user.id}/#{user.email}.\n\n")
  end
end
