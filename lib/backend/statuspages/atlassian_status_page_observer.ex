defmodule Backend.StatusPages.AtlassianStatusPageObserver do
  use GenServer
  require Logger

  @wait_time 120000 # 2 minutes

  def start_link(args) do
    monitor_logical_name = Keyword.fetch!(args, :monitor_logical_name)
    GenServer.start_link(__MODULE__, args, name: String.to_atom("#{__MODULE__}_#{monitor_logical_name}"))
  end

  @impl GenServer
  def init(args) do
    monitor_logical_name = Keyword.fetch!(args, :monitor_logical_name)
    url = Keyword.fetch!(args, :url)

    Process.send_after(self(), :work, :rand.uniform(@wait_time)) # stagger the first work hit to prevent exhausting hackney pool
    {:ok, %{monitor_logical_name: monitor_logical_name, url: url}}
  end

  @impl GenServer
  def handle_info(:work, state) do
    case Backend.StatusPages.AtlassianStatusPageScraper.scrape(state.url) do
      {:ok, []} -> Logger.error("Error running #{state.monitor_logical_name} statuspage scraper: got zero results. Page format changed?")
      {:ok, results} -> process_results(state.monitor_logical_name, results)
      {:error, reason} -> Logger.error("Error running #{state.monitor_logical_name} statuspage scraper from #{state.url}: #{reason}")
    end

    schedule_work()
    {:noreply, state, :hibernate}
  end

  # Explicit child spec so that id can be made unique in an encapsulated way for StatusPageObserverSupervisor
  def child_spec(args) do
    monitor_logical_name = Keyword.fetch!(args, :monitor_logical_name)
    %{
      id: monitor_logical_name,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  defp process_results(monitor_logical_name, results) do
    Logger.debug("#{monitor_logical_name} processing the following status page results: #{inspect(results)}")
    status_page = Backend.Projections.status_page_by_name(monitor_logical_name)

    id = case status_page do
      nil ->
        id = Domain.Id.new()
        Backend.App.dispatch(%Domain.StatusPage.Commands.Create{id: id, page: monitor_logical_name})
        id

      status_page ->
        status_page.id
    end

    Backend.App.dispatch(%Domain.StatusPage.Commands.ProcessObservations{
      id: id,
      page: monitor_logical_name,
      observations: results
    })
  end

  defp schedule_work() do
    # 2 minutes
    Process.send_after(self(), :work, @wait_time)
  end
end
