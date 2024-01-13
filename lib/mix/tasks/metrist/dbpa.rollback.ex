defmodule Mix.Tasks.Metrist.Dbpa.Rollback do
  use Mix.Task

  @shortdoc "Rolls back account migrations 1 step"

  @moduledoc """
  This Mix task performs a 1 step rollback in all account schemas. Only runs in the local
  environment for now.
  """

  @impl true
  def run(_args) do
    Mix.Tasks.Metrist.Helpers.start_repos("local")

    Backend.Repo.rollback_all_tenants()
  end
end
