defmodule Backend.StatusPages.AzureDevOpsStatusPageScraperTest do
  use ExUnit.Case, async: true
  require Logger

  alias Backend.StatusPages.AzureDevOpsStatusPageScraper

  test "Can parse azure dev ops sample into components" do
    {:ok, observations} = File.read!("test/backend/test_data/azure_dev_ops_status_page_example.html")
      |> AzureDevOpsStatusPageScraper.process_body()

    {_key, devops_observations} = Enum.find(observations, fn {key, _obs} -> key == "azuredevopsboards" end)
    assert List.first(devops_observations).status == "Unhealthy"
  end
end
