defmodule Backend.StatusPages.AwsStatusPageScraperTest do
  use ExUnit.Case, async: true
  require Logger

  alias Backend.StatusPages.AwsStatusPageScraper

  test "Can parse aws sample RSS into components" do
    component = File.read!("test/backend/test_data/ec2-us-east-1.rss")
      |> AwsStatusPageScraper.process_rss_body("us-east-1", "ec2")

    assert {"ec2", "Amazon Elastic Compute Cloud (N. Virginia) Service Status","us-east-1", "Good"} == component
  end
end
