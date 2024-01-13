defmodule Mix.Tasks.Metrist.OneOff.BackfillStatusPageComponentStates do
  use Mix.Task
  import Ecto.Query
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Backfills state for status page component changes"

  @opts [
    :env,
  ]

  @state_mapping %{
    :up => [
      "Good",
      "Information",
      "NotApplicable",
      "Avisory",
      "Advisory",
      "Healthy",
      "available",
      "operational"
    ],
    :degraded => [
      "Degraded",
      "Warning",
      "disruption",
      "degraded_performance",
      "under_maintenance"
    ],
    :down => [
      "Disruption",
      "Critical",
      "Unhealthy",
      "outage",
      "major_outage",
      "partial_outage"
    ]
  }

  @moduledoc """
  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)
    Helpers.start_repos(opts.env)

    IO.puts("Updating up changes")

    from(c in Backend.Projections.Dbpa.StatusPage.ComponentChange,
      where: c.status in ^@state_mapping[:up] and is_nil(c.state))
    |> put_query_prefix(Backend.Repo.schema_name("SHARED"))
    |> Backend.Repo.update_all(set: [state: :up])

    Process.sleep(100)

    IO.puts("Updating degraded changes")

    from(c in Backend.Projections.Dbpa.StatusPage.ComponentChange,
      where: c.status in ^@state_mapping[:degraded] and is_nil(c.state))
    |> put_query_prefix(Backend.Repo.schema_name("SHARED"))
    |> Backend.Repo.update_all(set: [state: :degraded])

    Process.sleep(100)

    IO.puts("Updating down changes")

    from(c in Backend.Projections.Dbpa.StatusPage.ComponentChange,
      where: c.status in ^@state_mapping[:down] and is_nil(c.state))
    |> put_query_prefix(Backend.Repo.schema_name("SHARED"))
    |> Backend.Repo.update_all(set: [state: :down])

    Process.sleep(100)

    from(c in Backend.Projections.Dbpa.StatusPage.ComponentChange,
      where: is_nil(c.state))
    |> put_query_prefix(Backend.Repo.schema_name("SHARED"))
    |> Backend.Repo.update_all(set: [state: :unknown])
  end
end
