defmodule Backend.StatusPages.GcpStatusPageScraper do
  alias Backend.StatusPages.Scraper

  @behaviour Scraper
  require Logger

  @service_map %{
    "Google App Engine" => "gcpappengine",
    "Google Cloud Storage" => "gcpcloudstorage",
    "Google Compute Engine" => "gcpcomputeengine",
    "Google Kubernetes Engine" => "gke",
    "Google Cloud SQL" => "gcpcloudsql",
    "Cloud Load Balancing" => "gcpcloudloadbalance",
    "Google BigQuery" => "gcpgooglebigquery",
    "Secret Manager" => "gcpsecretmanager",
    "Cloud Monitoring" => "gcpcloudmonitoring",
    "Cloud Logging" => "gcpcloudlogging",
    "Cloud Run" => "gcpcloudrun",
    "Cloud Memorystore" => "gcpcloudmemorystore",
    "Google Cloud Console" => "gcpcloudconsole",
    "Google Cloud Networking" => "gcpcloudnetworking",
    "Google Cloud Tasks" => "gcpcloudtasks",
    "Identity and Access Management" => "gcpidentityandaccessmanagement",
    "Virtual Private Cloud (VPC)" => "gcpvirtualprivatecloud"
  }

  @overview_page "https://status.cloud.google.com"
  @americas_page "https://status.cloud.google.com/regional/americas"

  @impl Scraper
  def name(), do: "GCP Status Page Scraper"

  @impl Scraper
  def scrape() do
    # scrape both pages for items in service map
    process_scrape_results(
      @overview_page |> scrape_page(),
      @americas_page |> scrape_page()
    )
  end

  def scrape_from_body_text(text) do
    process_body(text, @americas_page)
  end

  defp process_body(body, page) do
    status_table =
      Floki.parse_document!(body)
      # Google prefixes class names with random strings, probably to provide namespaces. Life is simpler without them.
      |> Floki.attr("[class]", "class", fn class ->
        String.replace(class, ~r/[A-Za-z0-9]+\_\_/, "")
      end)
      |> Floki.find("table.regional-table")

    locations =
      status_table
      |> Floki.find(page |> find_region_html())
      |> Enum.map(&Floki.text/1)
      |> Enum.reject(fn location ->
        location |> String.contains?("southamerica")
      end)

    status_table
    |> Floki.find("tbody > tr")
    |> Enum.map(fn component_row ->
      name =
        component_row
        |> Floki.find("th")
        |> Floki.text()
        |> String.trim()

      observations =
        component_row
        |> Floki.find("td")
        |> Enum.map(fn td -> Floki.find(td, "svg") |> Floki.attribute("class") |> List.first() end)
        |> Enum.zip(locations)
        |> Enum.filter(fn {status, _loc} -> not is_nil(status) end)
        |> Enum.map(fn {icon_state, region} ->

          status =
            icon_state
            |> String.replace("status-icon ", "")

          state =
            status
            |> Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state()

          %Domain.StatusPage.Commands.Observation{
            changed_at: NaiveDateTime.utc_now(),
            component: name,
            instance: region,
            status: status,
            state: state
          }
        end)

      {name, observations}
    end)
    |> Enum.map(fn {component, observations} ->
      {Map.get(@service_map, component), observations}
    end)
    |> Enum.reject(fn {service, _} -> is_nil(service) end)
  end

  defp scrape_page(page) do
    case HTTPoison.get(page) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, process_body(body, page)}
      {:ok, %HTTPoison.Response{}} -> {:error, "Non-200 status"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  defp process_scrape_results(scraped_overview, scraped_americas) do
    case { scraped_overview, scraped_americas } do
      {
        {:ok, overview_list},
        {:ok, americas_list}
      }  -> {:ok,
             # for duplicate gcp services, choose the one on americas page
             americas_list ++ overview_list
             |> Enum.uniq_by(fn {key, _} -> key end)
            }
      # assume if one page has error, then other also has an error
      _contains_error -> scraped_americas
    end
  end

  defp find_region_html(@overview_page) do
    "thead th.location"
  end
  defp find_region_html(@americas_page) do
    "thead th span.location-id"
  end

  def service_map, do: @service_map
end
