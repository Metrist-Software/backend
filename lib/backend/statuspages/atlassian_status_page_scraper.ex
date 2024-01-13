defmodule Backend.StatusPages.AtlassianStatusPageScraper do
  require Logger

  def scrape(url) do
    case HTTPoison.get(url, [], [hackney: [pool: :status_page_pool]]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        observations = process_body(body)
        |> remove_disallowed(url)

        {:ok, observations}
      {:ok, %HTTPoison.Response{}} -> {:error, "Non-200 status"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  def scrape_from_body_text(body), do: process_body(body)

  defp process_body(body) do
    Floki.parse_document!(body)
    |> Floki.find("div.component-container")
    |> Enum.map(fn container_div ->
      container_div
      |> Floki.find("div[data-component-id]")
      |> Enum.map_reduce(nil, fn component_div, current_parent ->
        parent_div = if length(component_div |> Floki.find("span.group-parent-indicator")) > 0 do
          component_div
        else
          current_parent
        end

        data_component_id = component_div |> Floki.attribute("data-component-id") |> List.first()
        status = component_div
                  |> Floki.attribute("data-component-status")
                  |> List.first()

        state = Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(status)

        {
          %Domain.StatusPage.Commands.Observation{
            data_component_id: data_component_id,
            changed_at: NaiveDateTime.utc_now(),
            component: get_expanded_name(parent_div, component_div),
            instance: nil,
            status: status,
            state: state
          },
          parent_div
        }
      end)
      |> elem(0)
    end)
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  defp get_name(component_div) do
    component_div
    |> Floki.find("span.name")
    |> Floki.text()
    |> String.trim()
  end

  defp get_expanded_name(nil, component_div), do: get_name(component_div)
  defp get_expanded_name(parent_div, component_div) when parent_div == component_div, do: get_name(component_div)
  defp get_expanded_name(parent_div, component_div), do: "#{get_name(parent_div)} - #{get_name(component_div)}"

  # This isn't pretty or scalable but it works for this as a one-off. If we find
  # more cases like this, then we'll need to figure out a better solution.
  # This specific component is hidden by javascript, so we can't do more generic
  # hidden component filtering without actually loading the page in a browser.
  defp remove_disallowed(observations, "https://www.githubstatus.com/") do
    Enum.reject(observations, fn %{component: component} ->
      component == "Visit www.githubstatus.com for more information"
    end)
  end
  # for new relic, only use US instances
  defp remove_disallowed(observations, "https://newrelic.statuspage.io/") do
    Enum.filter(observations, fn %{component: component} ->
      String.contains?(component, ": US")
    end)
  end
  defp remove_disallowed(components, _url), do: components

  def service_map(), do: Backend.StatusPage.Helpers.atlassian_status_pages()
end
