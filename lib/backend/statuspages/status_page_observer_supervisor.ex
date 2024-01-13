defmodule Backend.StatusPages.StatusPageObserverSupervisor do
  use Supervisor
  require Logger
  alias Backend.StatusPages

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    enabled = Backend.config([__MODULE__, :enabled])
    children = if enabled do
      :ok = :hackney_pool.start_pool(:status_page_pool, [timeout: 150000, max_connections: 100]) # create dedicated pool for status pages
      children = []

      children = for {monitor_logical_name, url} <- Backend.StatusPage.Helpers.atlassian_status_pages() do
        children ++ {Backend.StatusPages.AtlassianStatusPageObserver, [monitor_logical_name: monitor_logical_name, url: url] }
      end

      children = children ++ [
        {StatusPages.GenericStatusPageObserver, [scraper_module: StatusPages.AzureStatusPageScraper] },
        {StatusPages.GenericStatusPageObserver, [scraper_module: StatusPages.AzureDevOpsStatusPageScraper] },
        {StatusPages.GenericStatusPageObserver, [scraper_module: StatusPages.AwsStatusPageScraper] },
        {StatusPages.GenericStatusPageObserver, [scraper_module: StatusPages.GcpStatusPageScraper] }
      ]

      children
    else
      []
    end

    Logger.info("Starting the following status page observer children: #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_one)
  end
end
