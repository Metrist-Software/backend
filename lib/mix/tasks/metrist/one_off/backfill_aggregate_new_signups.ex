defmodule Mix.Tasks.Metrist.OneOff.BackfillAggregateNewSignups do

  use Mix.Task
  import Ecto.Query
  alias Mix.Tasks.Metrist.Helpers
  alias Backend.Projections.Aggregate.Common
  alias Backend.Repo
  require Logger

  @shortdoc "Backfills new accounts signup table with info from accounts aggregate "

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



    since = Common.since(1, :months)
    readquery = from a in Backend.Projections.Account,
    where:  a.inserted_at >= ^since,
    select: %{
      id: a.id,
      time: a.inserted_at,
    }
    queryrepo = Repo.all(readquery)
    Logger.warn(length(queryrepo))
    Enum.map(queryrepo, fn (row) ->
      {_ok, inserttime} = Ecto.Type.cast(:naive_datetime_usec,row.time)
    Ecto.Multi.insert(Ecto.Multi.new(), String.to_atom(row.id), %Backend.Projections.Aggregate.NewSignupAggregate{
        id: row.id,
        time: inserttime,
      },
      on_conflict: :nothing
      ) |> Repo.transaction() end)




  end
end
