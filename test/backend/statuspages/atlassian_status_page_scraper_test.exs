defmodule Backend.StatusPages.AtlassianStatusPageScraperTest do
  use ExUnit.Case, async: true
  require Logger

  alias Backend.StatusPages.AtlassianStatusPageScraper

  test "Can parse trello sample into components" do
    components = File.read!("test/backend/test_data/trello_status_page_example.html")
    |> AtlassianStatusPageScraper.scrape_from_body_text()

    %Domain.StatusPage.Commands.Observation{component: name, status: status} = List.first(components)
    assert length(components) == 5
    assert name == "Trello.com" && status == "operational"
  end

  test "Can parse status page with groupings and non operational statuses" do
    components = File.read!("test/backend/test_data/cloudflare_status_page_example.html")
    |> AtlassianStatusPageScraper.scrape_from_body_text()

    non_operational = Enum.filter(components, fn %Domain.StatusPage.Commands.Observation{status: status} -> status != "operational" end)

    assert length(non_operational) > 0
  end

  test "Gets proper/parent/child names" do
    components = File.read!("test/backend/test_data/zoom_status_page_example.html")
    |> AtlassianStatusPageScraper.scrape_from_body_text()

    zoom_website_components = Enum.filter(components, fn %Domain.StatusPage.Commands.Observation{component: component} -> String.starts_with?(component, "Zoom Website") end)

    assert length(zoom_website_components) == 6
  end
end
