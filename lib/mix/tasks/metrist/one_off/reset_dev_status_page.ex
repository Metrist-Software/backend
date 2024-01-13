defmodule Mix.Tasks.Metrist.OneOff.ResetDevStatusPage do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-847 Reset the status page aggregate state in dev1"

  def run(_args) do
    env = "dev1"
    Helpers.start_repos(env)
    Backend.Projections.Dbpa.StatusPage.status_pages()
    |> Enum.map(fn status_page ->
      %Domain.StatusPage.Commands.Reset{id: status_page.id}
    end)
    |> Helpers.send_commands(env, false)
  end

end
