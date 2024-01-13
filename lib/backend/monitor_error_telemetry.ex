defmodule Backend.MonitorErrorTelemetry do
  @moduledoc """
  Module to store and forward monitor errors so we can use that data in Grafana.
  """

  # Two things "wrong" here but for now, "meh":
  # - We have a separate GenServer call to update errors, meaning that AgentController needs to do a call. PubSub
  #   would be nicer, but subscriptions on PubSub, for now, are entity-based, not event-type-based. We can change that
  #   but having all these extraneous messages flowing for just this use case sounded like a bit much. If we touch it
  #   for Something Important™ we can always revisit that
  # - Maybe we should tag with instance, check, account id, ... - decision for now is to start simple, see whether it is
  #   valuable, and add more tagging when we see a need.
  #

  use GenServer
  use PromEx.Plugin
  require Logger

  # "Client" bits

  def start_link(args, name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @spec register_error(Domain.Monitor.Commands.AddError.t(), GenServer.server()) :: :ok
  def register_error(add_error_command, server \\ __MODULE__) do
    GenServer.cast(server, {:register_error, add_error_command})
  end

  # PromEx bits

  @metric_prefix [:backend, :monitor_error]

  @impl PromEx.Plugin
  def polling_metrics(opts, server \\ __MODULE__) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    Polling.build(
      :backend_monitor_error_metrics,
      poll_rate,
      {__MODULE__, :execute_metrics, [server]},
      [sum(
        @metric_prefix ++ [:count],
        description: "The number of errors received for the monitor",
        measurement: :count,
        tags: [:monitor]
      )]
    )
  end

  def execute_metrics(server \\ __MODULE__) do
    if GenServer.whereis(server) != nil do
      errors = GenServer.call(server, :errors)
      for {mon, error_count} <- errors do
        :telemetry.execute(@metric_prefix, %{count: error_count}, %{monitor: mon})
      end
    end
  end

  # GenServer bits

  @impl GenServer
  def init(_args) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:register_error, cmd}, error_map) do
    error_map = Map.update(error_map, cmd.id, 1, fn count -> count + 1 end)
    {:noreply, error_map}
  end

  @impl GenServer
  def handle_call(:errors, _from, error_map) do
    {:reply, error_map, %{}}
  end
end
