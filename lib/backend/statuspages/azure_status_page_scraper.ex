defmodule Backend.StatusPages.AzureStatusPageScraper do
  alias Backend.StatusPages.Scraper

  @behaviour Scraper
  require Logger

  @azure_service_map %{
    "Azure Kubernetes Service (AKS)" => "azureaks",
    "Azure Active Directory (Azure AD)" => "azuread",
    "Storage Accounts" => "azureblob",
    "Azure Cosmos DB" => "azuredb",
    "Virtual Machines" => "azurevm",
    "App Service" => "azureappservice",
    "App Service (Linux)" => "azureappservice",
    "Content Delivery Network" => "azurecdn",
    "Azure Functions" => "azurefncs",
    "Azure Monitor" => "azuremonitor",
    "Azure SQL Database" => "azuresql"
  }

  @azure_region_map %{
    "East US" => "az:eastus",
    "East US 2" => "az:eastus2",
    "West US" => "az:westus",
    "West US 2" => "az:westus2",
    "South Central US" => "az:southcentralus",
    "Central US" => "az:centralus",
    "Canada Central" => "az:canadacentral",
    "*Non-Regional" => :global
  }

  @impl Scraper
  def name(), do: "Azure Status Page Scraper"

  @impl Scraper
  def scrape() do
    case HTTPoison.get("https://azure.status.microsoft/en-us/status") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, process_body(body)}
      {:ok, %HTTPoison.Response{}} -> {:error, "Non-200 status"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  def process_body(body) do
    html = Floki.parse_document!(body)
    status_table = Floki.find(html, "table.region-status-table[data-zone-name='americas']")

    # Get list of regions from table header. Remove first entry, corresponding to the `PRODUCTS AND SERVICES` column
    [_ | regions] = Floki.find(status_table, "th > span")
    |> Enum.map(fn node -> Floki.text(node, deep: false) end)

    # Get region/status pairs for each service (row)
    Floki.find(status_table, "tbody > tr")
    |> Floki.filter_out(".status-category, .capability-row")
    |> Enum.map(fn row ->
      [head | cols] = Floki.find(row, "td")

      service = Floki.text(head)
                |> String.trim()

      statuses = Enum.map(cols, fn col ->
        case Floki.attribute(col, "class") do
          ["status-cell"] -> Floki.find(col, "span")
                              |> Floki.attribute("data-label")
                              |> Floki.text()
                              |> String.trim()
          _ -> nil
        end
      end)

      # Map and filter regions based on our supported regions

      observations = Enum.zip(regions, statuses)
      |> Enum.map(fn {region, status} -> {String.trim(region), status} end)
      |> Enum.map(fn {region, status} -> {Map.get(@azure_region_map, region), status} end)
      |> Enum.reject(fn {region, status} -> is_nil(region) || is_nil(status) || status == "Not" || status == "" end)
      |> Enum.map(fn {region, status} ->
        state = Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(status)


        %Domain.StatusPage.Commands.Observation{
          changed_at: NaiveDateTime.utc_now(),
          component: service,
          instance: region,
          status: status,
          state: state
        }
      end)

      {service, observations}
    end)
    |> Enum.map(fn {service, observations} -> {Map.get(@azure_service_map, service), observations} end)
    |> Enum.reject(fn {service, _} -> is_nil(service) end)
    |> Enum.group_by(fn {key, _value} -> key end, fn {_key, value} -> value end)
    |> Enum.map(fn {key, value} -> {key, List.flatten(value)} end)
  end

  def service_map, do: @azure_service_map
end
