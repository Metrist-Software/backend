defmodule Backend.StatusPages.AzureStatusPageScraperTest do
  use ExUnit.Case, async: true
  require Logger

  alias Backend.StatusPages.AzureStatusPageScraper

  test "Can parse new page into components" do
    body = File.read!("test/backend/test_data/azure_status_page_example.html")

    res = AzureStatusPageScraper.process_body(body)

    {_key, azure_observations} = Enum.find(res, fn {key, _obs} -> key == "azuremonitor" end)
    assert List.first(azure_observations).status == "Good"
  end
end
