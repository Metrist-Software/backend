defmodule Mix.Tasks.Metrist.OneOff.BackfillIssueSources do
  use Mix.Task
  import Ecto.Query
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Backfills sources for Issues from the associated IssueEvents"

  @opts [
    :env,
  ]


  @moduledoc """
  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)
    Helpers.start_repos(opts.env)

    account_ids = Backend.Projections.Account.list_account_ids()

    for account_id <- account_ids do
      issues = from(i in Backend.Projections.Dbpa.Issue)
      |> put_query_prefix(Backend.Repo.schema_name(account_id))
      |> preload([:events])
      |> Backend.Repo.all()

      for issue <- issues do
        sources = issue.events
        |> Enum.map(& &1.source)
        |> Enum.uniq()

        issue
        |> Ecto.Changeset.change(sources: sources)
        |> Backend.Repo.update()
      end
    end
  end
end
