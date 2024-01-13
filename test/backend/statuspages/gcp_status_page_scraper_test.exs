defmodule Backend.StatusPages.GcpStatusPageScraperTest do
  use ExUnit.Case, async: true
  require Logger

  alias Backend.StatusPages.GcpStatusPageScraper

  test "Can parse gcp sample into components by service" do
    components =
      File.read!("test/backend/test_data/google_status_page_example.html")
      |> GcpStatusPageScraper.scrape_from_body_text()

    assert Enum.any?(components, fn {id, observations} ->
             id == "gke" &&
               Enum.any?(observations, fn %Domain.StatusPage.Commands.Observation{
                                            component: name,
                                            status: status,
                                            state: state
                                          } ->
                 name == "Google Kubernetes Engine" && status == "disruption" &&
                   state == :degraded
               end)
           end)
  end
end
