defmodule Backend.StatusPages.Scraper do
  @callback name() :: String.t
  @callback scrape() :: {:ok, [{String.t, [%Domain.StatusPage.Commands.Observation{}]}]} | {:error, String.t}
end
