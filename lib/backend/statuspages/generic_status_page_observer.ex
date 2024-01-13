defmodule Backend.StatusPages.GenericStatusPageObserver do
  use GenServer
  require Logger

  @wait_time 120000 # 2 minutes

  def start_link(args) do
    scraper_module = Keyword.fetch!(args, :scraper_module)
    GenServer.start_link(__MODULE__, args, name: String.to_atom("#{__MODULE__}_#{scraper_module}"))
  end

  @impl true
  def init(args) do
    scraper_module = Keyword.fetch!(args, :scraper_module)
    send(self(), :work)
    {:ok, %{scraper: scraper_module}}
  end

  @impl true
  def handle_info(:work, %{scraper: scraper} = state) do
    case scraper.scrape() do
      {:ok, []} ->
        Logger.error("Error running #{scraper.name()} statuspage scraper: got zero results. Page format changed?")
      {:ok, results} ->
        process_results(results)
      {:error, reason} ->
        Logger.error("Error running #{scraper.name()} statuspage scraper: #{reason}")
    end

    schedule_work()
    {:noreply, state, :hibernate}
  end

  def child_spec(args) do
    scraper = Keyword.fetch!(args, :scraper_module)
    %{
      id: scraper.name(),
      start: {__MODULE__, :start_link, [args]}
    }
  end

  defp process_results(results) do
    for {service, observations} <- results do
      # Get existing status page entry; create one if it doesn't exist
      status_page = Backend.Projections.status_page_by_name(service)

      id = case status_page do
        nil ->
          id = Domain.Id.new()
          Backend.App.dispatch(%Domain.StatusPage.Commands.Create{id: id, page: service})
          Logger.info("Created new status page entry for #{service} with id #{id}")
          # There's a small risk that we have multiple observations for the same
          # service in the set, in which case on the next round, we'd create it again
          # given that it is unlikely that in such a tight loop the projection behind
          # `status_page_by_name` is already updated. So let's wait a bit before continuing.
          Process.sleep(5_000)
          id

        status_page ->
          status_page.id
      end

      Backend.App.dispatch(%Domain.StatusPage.Commands.ProcessObservations{
        id: id,
        page: service,
        observations: observations
      })
    end
  end

  defp schedule_work() do
    # 2 minutes
    Process.send_after(self(), :work, @wait_time)
  end
 end
