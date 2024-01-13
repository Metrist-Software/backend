defmodule Mix.Tasks.Metrist.OneOff.BackfillUserAddedEvents do
  use Mix.Task
  import Ecto.Query
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc "Backfills UserAdded events by dispatching AddUser commands for every existing invite"

  @opts [
    :env,
    :dry_run,
  ]

  @moduledoc """
  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Helpers.start_repos(options.env)

    account_ids = Backend.Projections.Account.list_accounts()
    |> Enum.map(& &1.id)

    users = Backend.Projections.User.list_users()
    |> Enum.reject(& is_nil(&1.account_id))
    |> Enum.reject(& !Enum.member?(account_ids, &1.account_id))

    users
    |> Enum.map(fn user ->
      %Domain.Account.Commands.AddUser{
        id: user.account_id,
        user_id: user.id
      }
    end)
    |> Helpers.send_commands(options.env, options.dry_run)

    user_counts = users
    |> Enum.group_by(& &1.account_id)
    |> Enum.map(fn {account_id, users} -> {account_id, Enum.count(users)} end)

    Logger.info("Sleeping 5s to let commands process...")
    Process.sleep(5_000)

    Enum.reduce(user_counts, Ecto.Multi.new(), fn {account_id, count}, multi ->
      Logger.info("Setting #{account_id} user count to #{count}")
      query =
        from a in Backend.Projections.Account,
        where: a.id == ^account_id,
        update: [set: [{:stat_num_users, ^count}]]

      Ecto.Multi.update_all(multi, String.to_atom(account_id), query, [])
    end)
    |> Backend.Repo.transaction()
  end
end
