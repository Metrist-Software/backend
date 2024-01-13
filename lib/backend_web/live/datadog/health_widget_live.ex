defmodule BackendWeb.Datadog.HealthWidgetLive do
@moduledoc """
This widget pulls results in realtime from metrist-created tagged datadog synthetics
via Framepost API queries and provides a simple red/yellow/green health status
dashboard

It automatically refreshes the data once every 60s
"""
  use BackendWeb, :dd_live_view

  require Logger

  @metrist_tag "metrist-created"

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(
        results: [],
        loaded: false
      )
    }
  end

  @impl true
  def render(%{loaded: false} = assigns) do
    ~H"""
    <div id="health-widget" phx-hook="DatadogHealthWidget" class="w-fit m-auto">
      Loading Data...
    </div>
    """
  end

  def render(%{loaded: true, results: []} = assigns) do
    ~H"""
    <div id="health-widget" phx-hook="DatadogHealthWidget" class="w-full flex flex-col justify-center">
      <p class="text-center my-5">It looks like you don't have any Metrist monitors added. Click below to set them up.</p>
      <.button color="primary" label="Add Monitors" class="m-auto" phx-click="open_synthetics_wizard"/>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="health-widget" phx-hook="DatadogHealthWidget" class="w-full p-3">
      <ul class="grid sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
        <li :for={test <- @results}>
          <a href="#" class="monitor-card-link" class="cursor-pointer" data-id={get_public_id(test)}>
            <.get_card test={test} />
          </a>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def handle_info(:refresh, socket) do
    {
      :noreply,
      socket
      |> push_event("refresh_data", %{})
    }
  end

  @impl true
  def handle_event("tests-loaded", value, socket) do
    results =
      value
      |> Enum.filter(fn test ->
        test
        |> get_tags()
        |> Enum.member?(@metrist_tag)
      end)
      |> Enum.sort_by(&(Map.get(&1, "name")))

    # Refresh every 60s
    Process.send_after(self(), :refresh, 60_000)

    # Only auto-open the synthetics wizard on the initial load
    socket = if socket.assigns.loaded == false && results == [] do
      push_event(socket, "open_synthetics_wizard", %{})
    else
      socket
    end

    {
      :noreply,
      socket
      |> assign(
        results: results,
        loaded: true
      )
    }
  end

  def handle_event("open_synthetics_wizard", _, socket) do
    {:noreply, push_event(socket, "open_synthetics_wizard", %{})}
  end

  def get_card(assigns) do
    ~H"""
      <div class={"flex flex-col overflow-hidden border-l-8 border rounded-lg p-3 text-sm h-full #{monitor_border_class(@test)}"}>
        <h3 class="font-bold">
          <%= get_name(@test) %>
        </h3>

        <div classs="text-xs">
          Probes: <%= Enum.join(get_locations(@test), ",") %>
        </div>

        <div class="flex-grow" />

        <div>
          <BackendWeb.Components.MonitorStateBadge.render
            state={get_state(@test)}
            class="py-1 px-2 mt-1 mr-1 w-18 h-18"
            show_icon={false}
            badge_font_class=""
          />
        </div>
      </div>
    """
  end

  # Left public for testing

  @doc """
  Simple degraded check which simply averages out all returned timings per probe
  other than the most recent one and then compares 5x that to the most recent timing.
  Will likely want to make this more complex in the future.any()
  If any probe exceeds the inflated average, the check is considered degraded
  This is only called by get_state/1 which checks is_down?/is_issues? first
  """
  def is_degraded?(%{"results" => results}) when length(results) <= 1, do: false
  def is_degraded?(%{"results" => results}) do
    latest_results_per_probe = get_latest_result_details_per_probe(results)

    results
      |> Enum.group_by(&(Map.get(&1, "probe_dc")))
      |> Enum.any?(fn {probe, values} ->
        # Include everything except the most recent result in the average calculation
        [_most_recent_value | rest] = values

        case length(rest) do
          0 -> false
          _ ->
            average =
              rest
              |> Enum.map(&(get_timing(Map.get(&1, "result"))))
              |> Enum.sum()
              |> Kernel./(length(rest))

            latest_results_per_probe[probe].timing > (average * 5.0)
        end
      end
      )
  end

  @doc """
  Simple down calculation. All probes have to be failing for this to return true.
  This is only called by get_state/1
  """
  def is_down?(%{"results" => results}) when length(results) == 0, do: false
  def is_down?(%{"results" => results}) do
    results
    |> get_latest_result_details_per_probe()
    |> Enum.all?(fn {_probe, details} ->
      !details.passed
    end)
  end

  @doc """
  Simple issues calculation. At least one probe has to be failing for this to return true.
  This is only called by get_state/1 which checks is_down? first so no need to check for that here
  """
  def is_issues?(%{"results" => results}) when length(results) == 0, do: false
  def is_issues?(%{"results" => results}) do
    results
      |> get_latest_result_details_per_probe()
      |> Enum.any?(fn {_probe, details} ->
        !details.passed
      end)
  end

  @doc """
  Relative priority and returning unknown if we have no results.
  """
  def get_state(test) do
    test_with_filtered_results =
      test
      |> Map.put("results", filter_results_to_past_week(Map.get(test, "results")))

    cond do
      is_down?(test_with_filtered_results) -> :down
      is_issues?(test_with_filtered_results) -> :issues
      is_degraded?(test_with_filtered_results) -> :degraded
      length(Map.get(test_with_filtered_results, "results")) > 0 -> :up
      true -> :unknown
    end
  end

  # Other Helpers

  defp get_name(test), do: Map.get(test, "name")
  defp get_tags(test), do: Map.get(test, "tags")
  defp get_locations(test), do: Map.get(test, "locations")
  defp get_public_id(test), do: Map.get(test, "public_id")

  defp get_latest_result_details_per_probe(results) when length(results) == 0, do: %{}
  defp get_latest_result_details_per_probe(results) do
    results
    |> Enum.group_by(&(Map.get(&1, "probe_dc")))
    |> Enum.map(fn {probe, results} ->
      most_recent_result =
        Enum.at(results, 0)
        |> Map.get("result")

      # completed_steps & total_steps can be nil if this is a single step test
      completed_steps = Map.get(most_recent_result, "stepCountCompleted")
      total_steps = Map.get(most_recent_result, "stepCountTotal")
      passed = Map.get(most_recent_result, "passed")
      {probe, %{completed_steps: completed_steps, total_steps: total_steps, passed: passed, timing: get_timing(most_recent_result)}}
    end)
    |> Map.new()
  end

  # Single step result structures are different than multi step result structures
  def get_timing(result) when is_map_key(result, "duration") do
    result
    |> Map.get("duration")
  end

  def get_timing(result) when is_map_key(result, "timings") do
    result
    |> Map.get("timings")
    |> Map.get("total")
  end

  defp monitor_border_class(test) do
    case get_state(test) do
      :up -> "border-gray-500 border-l-healthy"
      state -> "#{BackendWeb.Helpers.get_monitor_status_border_class(state)}"
    end
  end

  defp filter_results_to_past_week(results) do
    seven_days_ago =
      DateTime.utc_now()
      |> Timex.add(Timex.Duration.from_days(-7))
      |> DateTime.to_unix(:millisecond)

    # Most of the time this will not have to filter as DD only returns the most recent 50 results
    # So we will in most cases avg the last 50 and then check for degradation
    # Making tons of API calls to get more than the last 50 isn't viable
    results
    |> Enum.filter(fn result ->
      Map.get(result, "check_time") >= seven_days_ago
    end)
  end
end
