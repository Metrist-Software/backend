defmodule Mix.Tasks.Metrist.Reporting.StatusPageScraper do
  use Mix.Task
  import Ecto.Query

  alias Backend.Projections
  alias Backend.Projections.Dbpa.StatusPage
  alias Backend.Repo

  alias Backend.StatusPages.AtlassianStatusPageScraper
  alias Backend.StatusPages.AwsStatusPageScraper
  alias Backend.StatusPages.AzureDevOpsStatusPageScraper
  alias Backend.StatusPages.AzureStatusPageScraper
  alias Backend.StatusPages.GcpStatusPageScraper

  alias BackendWeb.Helpers, as: WebHelpers
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "Reporting functions to introspect on status page issues"

  @opts [
    :env,
    :dry_run
  ]

  @moduledoc """
  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  # MIX_ENV=prod mix metrist.reporting.status_page_scraper -e prod
  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Application.ensure_all_started(:hackney)
    Helpers.start_repos(options.env)
    Logger.configure(level: :info)

    # fetch status pages
    status_pages =
      from(sp in StatusPage)
      |> put_query_prefix(Repo.schema_name(Domain.Helpers.shared_account_id()))
      |> Repo.all()

    report_on_status_change_limits(status_pages, "Etc/UTC", "90day")
    report_on_page_component_counts(status_pages)
  end

  def report_on_page_component_counts(status_pages) do
    # right now it's just Atlassian status pages that are having the issue of duplicate component names, so just report on those...
    status_pages
    |> status_page_names()
    |> dedup_name_filter([])
    |> IO.inspect(label: [IO.ANSI.yellow()])
    |> Enum.reduce(%{}, fn name, acc ->
      case status_page_observer_type(name) do
        :atlassian ->
          url = Map.get(AtlassianStatusPageScraper.service_map(), name)
          {:ok, results} = AtlassianStatusPageScraper.scrape(url)
          Map.merge(acc, %{name => results})

        :aws ->
          {:ok, results} = AwsStatusPageScraper.scrape()
          Map.merge(acc, process_non_atlassian_results(results))

        :azure ->
          {:ok, results} = AzureStatusPageScraper.scrape()
          Map.merge(acc, process_non_atlassian_results(results))

        :azure_devops ->
          {:ok, results} = AzureDevOpsStatusPageScraper.scrape()
          Map.merge(acc, process_non_atlassian_results(results))

        :gcp ->
          {:ok, results} = GcpStatusPageScraper.scrape()
          Map.merge(acc, process_non_atlassian_results(results))

        :noop ->
          acc
      end
    end)
    |> Enum.reduce(%{}, fn {page_name, results}, acc ->
      stats =
        results
        |> Enum.frequencies_by(fn page_comp -> {page_comp.component, page_comp.instance} end)

      Map.merge(acc, %{page_name => Enum.into(stats, %{})})
    end)
    |> Enum.map(fn scrape_result ->
      write_to_file(scrape_result)
      scrape_result
    end)
    |> Enum.each(fn {page_name, stats} ->
      IO.inspect("#{page_name} has component frequencies:", label: [IO.ANSI.cyan()])

      stats
      |> Enum.each(&IO.inspect(&1, label: [IO.ANSI.magenta()]))
    end)
  end

  def report_on_status_change_limits(status_pages, timezone, timespan) do
    _status_page_status_map =
      status_pages
      |> status_page_names()
      |> Enum.reduce(%{}, fn page_name, acc ->
        Map.merge(acc, %{page_name => statuses_from_page_name(page_name, timezone, timespan)})
      end)
      |> Enum.each(fn {page_name, statuses} ->
        if length(statuses) >= Projections.status_page_limit() do
          IO.inspect(
            "#{page_name} has #{length(statuses)} statuses and won't display on timeline",
            label: [IO.ANSI.yellow()]
          )
        end
      end)
  end

  def status_page_names(status_pages) do
    status_pages
    |> Enum.map(& &1.name)
  end

  def statuses_from_page_name(status_page_name, timezone, timespan) do
    Projections.status_page_changes(status_page_name, timespan)
    |> Enum.map(fn change ->
      %{
        date: WebHelpers.datetime_to_tz(change.changed_at, timezone),
        state: Projections.status_page_status_to_snapshot_state(change.status)
      }
    end)
    |> Enum.reject(&(&1.state == :unknown))
  end

  def status_page_observer_type(name) do
    cond do
      name in Map.keys(AtlassianStatusPageScraper.service_map()) -> :atlassian
      name in Map.values(AwsStatusPageScraper.service_map()) -> :aws
      name in Map.values(AzureStatusPageScraper.service_map()) -> :azure
      name in Map.values(AzureDevOpsStatusPageScraper.service_map()) -> :azure_devops
      name in Map.values(GcpStatusPageScraper.service_map()) -> :gcp
      true -> :noop
    end
  end

  # since aws, azure, azure_devops, gcp scrapers scrape everything all at once, just need one of the status page names to ask for a scrape
  defp dedup_name_filter([name | rest] = _status_page_names, filter_acc) do
    cond do
      status_page_observer_type(name) in [:aws] and
          !Enum.any?(filter_acc, &(status_page_observer_type(&1) in [:aws])) ->
        dedup_name_filter(rest, [name | filter_acc])

      status_page_observer_type(name) in [:azure] and
          !Enum.any?(filter_acc, &(status_page_observer_type(&1) in [:azure])) ->
        dedup_name_filter(rest, [name | filter_acc])

      status_page_observer_type(name) in [:azure_devops] and
          !Enum.any?(filter_acc, &(status_page_observer_type(&1) in [:azure_devops])) ->
        dedup_name_filter(rest, [name | filter_acc])

      status_page_observer_type(name) in [:gcp] and
          !Enum.any?(filter_acc, &(status_page_observer_type(&1) in [:gcp])) ->
        dedup_name_filter(rest, [name | filter_acc])

      status_page_observer_type(name) in [:atlassian] ->
        dedup_name_filter(rest, [name | filter_acc])

      true ->
        dedup_name_filter(rest, filter_acc)
    end
  end

  defp dedup_name_filter([], filter_acc), do: filter_acc

  defp process_non_atlassian_results(results) do
    results
    |> List.flatten()
    |> Enum.reduce(%{}, fn {comp_name, results}, acc ->
      Map.merge(acc, %{comp_name => results})
    end)
  end

  defp write_to_file({page_name, stats}, file_name \\ "../scrape_results.txt") do
    File.write!(file_name, inspect(page_name <> ":"), [:append, :binary])
    File.write!(file_name, "\n", [:append, :binary])

    stats
    |> Enum.each(fn {{_comp, _instance}, count} = stat ->
      File.write!(file_name, inspect(stat), [:append, :binary])
      if count > 1 do
        File.write!(file_name, inspect(" <<duplicate"), [:append, :binary])
      end
      File.write!(file_name, "\n", [:append, :binary])
    end)

    File.write!(file_name, "\n\n", [:append, :binary])
  end
end
