defmodule BackendWeb.Admin.MetricsLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Metrics",
        metrics: %Backend.Metrics{},
        active_user_areas: ["Web", "Slack", "Teams"]
        )
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    if connected?(socket) do
      {:noreply, assign(socket, metrics: Backend.ScheduledMetrics.get())}
    else
      {:noreply, socket}
    end
  end

  def formatter(f), do: :erlang.float_to_binary(f, decimals: 0)

  defp get_active_user_action("Web"), do: "logged into the"
  defp get_active_user_action(_), do: "interacted with"

  # 2023H1 KPI: Orchestrator installs >= 100 by July 1st.
  @installs_target 100
  @installs_deadline ~N[2023-07-01T00:00:00.000]
  @installs_start    ~N[2023-03-15T00:00:00.000]

  @target_length NaiveDateTime.diff(@installs_deadline, @installs_start, :second)

  def target, do: @installs_target
  def deadline, do: @installs_deadline

  def momentary_target do
    left = NaiveDateTime.diff(@installs_deadline, NaiveDateTime.utc_now(), :second)
    left = (@target_length - left) / @target_length
    max(1, round(left * @installs_target))
  end

  def on_target?(metrics), do: metrics.orchestrator_count.total >= momentary_target()

  def variant_for_on_target(metrics) do
    if on_target?(metrics) do
      :success
    else
      :danger
    end
  end
end
