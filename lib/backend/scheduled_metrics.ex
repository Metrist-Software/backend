defmodule Backend.ScheduledMetrics do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: ScheduledMetrics)
  end

  def get(), do: GenServer.call(ScheduledMetrics, :get)

  @impl true
  def init(_args) do
    send(self(), :work)

    {:ok, %Backend.Metrics{}}
  end

  @impl true
  def handle_call(:get, _from, current_metrics), do: {:reply, current_metrics, current_metrics}

  @impl true
  def handle_info(:work, current_metrics) do
    Logger.info("Updating metrics")

    metrics = try do
      Backend.Metrics.fetch()
    rescue
      error ->
        Logger.warn("Could not update metrics, error is #{inspect error}.")
        current_metrics
    end

    try do
      Backend.Metrics.cleanup()
    rescue
      error ->
        Logger.warn("Could not cleanup metrics, error is #{inspect error}.")
    end

    Logger.info("Finished updating metrics")

    schedule_work()
    {:noreply, metrics}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, :timer.minutes(30))
  end
end
