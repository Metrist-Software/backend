defmodule Mix.Tasks.Metrist.Dbpa.Migrate do
  use Mix.Task

  @shortdoc "Runs all account migrations"

  @moduledoc """
  This Mix task runs migrations in all account schemas. Only runs in the local environment for now.
  """

  @impl true
  def run(_args) do
    Mix.Tasks.Metrist.Helpers.start_repos("local")

    Backend.Repo.migrate_all_tenants()
  end
end
