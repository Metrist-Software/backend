defmodule Backend.StatusPages.AzureDevOpsStatusPageScraper do
  alias Backend.StatusPages.Scraper

  @behaviour Scraper
  require Logger

  @azure_service_map %{
    "Repos" => "azuredevops",
    "Artifacts" => "azuredevopsartifacts",
    "Boards" => "azuredevopsboards",
    "Pipelines" => "azuredevopspipelines",
    "Test Plans" => "azuredevopstestplans"
  }

  @azure_region_map %{
    "US" => "az:centralus"
    # if we start running elsewhere
    # ,"CA" => "az:canadacentral"
  }

  @azure_status_map %{
    0 => "NotApplicable",
    1 => "Unhealthy",
    2 => "Degraded",
    3 => "Advisory",
    4 => "Healthy"
  }

  @impl Scraper
  def name(), do: "Azure DevOps Status Page Scraper"

  @impl Scraper
  def scrape() do
    case HTTPoison.get("https://status.dev.azure.com/") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> process_body(body)
      {:ok, %HTTPoison.Response{}} -> {:error, "Non-200 status"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  def process_body(body) do
    # changes to the actual page we are parsing are out of our control so rescue and log if we can't parse
    # for instance if a node name gets changed in the included data within the embedded <script> tag
    try do
      html = Floki.parse_document!(body)
      observations =
        Floki.find(html, "script#dataProviders")
        |> Floki.FlatText.get()
        |> Jason.decode!()
        |> Map.get("data")
        |> Map.get("ms.vss-status-web.public-status-data-provider")
        |> Map.get("serviceStatus")
        |> Map.get("services")
        |> Enum.map(&do_process_individual_service/1)
        |> List.flatten()
        # Anything that has a nil service or instance we haven't mapped and don't care about
        |> Enum.reject(fn observation -> is_nil(observation.instance) end)
        |> Enum.group_by(fn observation -> observation.component end, fn observation -> observation end)
        |> Enum.map(fn {key, list} -> {Map.get(@azure_service_map, key), List.flatten(list)} end)
        |> Enum.reject(fn {key, _list} -> is_nil(key) end)

      {:ok, observations}
    rescue
      error ->
        Logger.error("Error processing the azure dev ops status page in #{__MODULE__}. #{inspect(error)}")
        {:error, error}
    end
  end

  defp do_process_individual_service(individual_service_map) do
    service = Map.get(individual_service_map, "id")

    Map.get(individual_service_map, "geographies")
    |> Enum.map(&do_process_individual_geography(&1, service))
  end

  defp do_process_individual_geography(individual_geography, service) do
    region = Map.get(@azure_region_map, Map.get(individual_geography, "id"))
    status = Map.get(@azure_status_map, Map.get(individual_geography, "health"))
    state = Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(status)

    %Domain.StatusPage.Commands.Observation{
      changed_at: NaiveDateTime.utc_now(),
      component: service,
      instance: region,
      status: status,
      state: state
    }
  end

  def service_map, do: @azure_service_map
end
