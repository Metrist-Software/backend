defmodule Backend.MonitorAgeTelemetry do
  @moduledoc """
  Module to calculate whether monitors are run often enough, based on the
  concept of "relative age" which is how long ago the last time was, on
  poll, we saw data versus the configured interval. By making the age
  relative, we can export an actional number to Prometheus/Grafana so
  we don't have to duplicate configuration.

  We only will do this for SHARED monitoring for now. Note that we will
  only pick up monitor configuration at startup.
  """

  use GenServer
  use PromEx.Plugin
  require Logger

  defmodule State do
    defstruct [:configured_intervals, :monitor_times, :instance_times, :initialized, :start_time]
  end

  def start_link(args, name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def process_telemetry(e, server \\ __MODULE__)

  def process_telemetry(e = %Domain.Monitor.Events.TelemetryAdded{account_id: "SHARED"}, server) do
    GenServer.cast(server, {:telemetry, e})
  end

  def process_telemetry(e, _server) do
    Logger.debug("Monitor age telemetry: Ignore non-shared telemetry #{inspect(e)}")
  end

  def process_error(e, server \\ __MODULE__)

  def process_error(e = %Domain.Monitor.Events.ErrorAdded{account_id: "SHARED"}, server) do
    GenServer.cast(server, {:error, e})
  end

  def process_error(e, _server) do
    Logger.debug("Monitor age telemetry: Ignore non-shared error #{inspect(e)}")
  end

  # PromEx bits

  @metric_prefix [:backend, :monitor_age]

  @impl PromEx.Plugin
  def polling_metrics(opts, server \\ __MODULE__) do
    Logger.info("Monitor age telemetry: Polling for metrics opts are #{inspect(opts)}")
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    Polling.build(
      :backend_monitor_age_metrics,
      poll_rate,
      {__MODULE__, :execute_metrics, [server]},
      [
        last_value(
          @metric_prefix ++ [:relative_age],
          description: "The relative age of the last monitoring data received",
          measurement: :relative_age,
          tags: [:monitor]
        ),
        last_value(
          @metric_prefix ++ [:instance_age],
          description: "The absolute age since we received any data from an instance",
          measurement: :instance_age,
          tags: [:instance],
          unit: :second
        )
      ]
    )
  end

  def execute_metrics(server \\ __MODULE__, telemetry_execute \\ &:telemetry.execute/3) do
    if GenServer.whereis(server) != nil do

      for {mon, rel_age} <- GenServer.call(server, :ages) do
        mon = String.to_atom(mon)
        telemetry_execute.(@metric_prefix, %{relative_age: rel_age}, %{monitor: mon})
      end

      for {ins, age} <- GenServer.call(server, :instances) do
        ins = String.to_atom(ins)
        telemetry_execute.(@metric_prefix, %{instance_age: age}, %{instance: ins})
      end
    end
  end

  # GenServer bits

  @impl GenServer
  def init(_args) do
    {:ok,
     %State{
       configured_intervals: %{},
       monitor_times: %{},
       instance_times: %{},
       initialized: false
     }, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_arg, state) do
    do_handle_continue(state)
  end

  @impl GenServer
  def handle_cast({:telemetry, e = %Domain.Monitor.Events.TelemetryAdded{}}, state) do
    {:noreply,
     %State{
       state
       | monitor_times: Map.put(state.monitor_times, monitor_key(e), e.created_at),
         instance_times: Map.put(state.instance_times, instance_key(e), e.created_at)
     }}
  end

  @impl GenServer
  def handle_cast({:error, e = %Domain.Monitor.Events.ErrorAdded{}}, state) do
    {:noreply,
     %State{
       state
       | monitor_times: Map.put(state.monitor_times, monitor_key(e), e.time),
         instance_times: Map.put(state.instance_times, instance_key(e), e.time)
     }}
  end

  @impl GenServer
  def handle_call(_, _from, state = %State{initialized: false}) do
    {:reply, [], state}
  end

  def handle_call(:ages, _from, state) do
    do_ages(state)
  end

  def handle_call(:instances, _from, state) do
    do_instances(state)
  end

  # Public for testing.

  @doc false
  def do_handle_continue(
        state,
        get_monitor_configs \\ &Backend.Projections.get_monitor_configs/1,
        clock \\ &NaiveDateTime.utc_now/0
      ) do
    try do
      configured_intervals =
        for mc <- get_monitor_configs.("SHARED") do
          {monitor_key(mc), mc.interval_secs}
        end
        |> Map.new()

      {:noreply,
       %State{
         state
         | configured_intervals: configured_intervals,
           start_time: clock.(),
           initialized: true
       }}
    rescue
      error ->
        Logger.error(
          "Error on initialization of #{__MODULE__}, retry after sleep: #{inspect(error)}"
        )

        Process.sleep(1_000)
        {:noreply, state, {:continue, nil}}
    end
  end

  @doc false
  def do_ages(
        state,
        get_monitor_configs \\ &Backend.Projections.get_monitor_configs/1,
        clock \\ &NaiveDateTime.utc_now/0
      ) do
    reply =
      for mc <- get_monitor_configs.("SHARED") do
        # If we never observed a monitor, we pretend we observed it when we started. This allows
        # us to start up assuming everything is green, and relative times will eventually creep
        # up from there to cause an alert.
        last_observed_time = Map.get(state.monitor_times, monitor_key(mc), state.start_time)
        last_observed_age = NaiveDateTime.diff(clock.(), last_observed_time, :second)
        relative_age = last_observed_age / mc.interval_secs
        {monitor_key(mc), relative_age}
      end

    {:reply, reply, state}
  end

  @doc false
  def do_instances(
        state,
        get_active_monitor_instance_names \\ &Backend.Projections.get_active_monitor_instance_names/1,
        clock \\ &NaiveDateTime.utc_now/0) do

    reply =
      for instance_name <- get_active_monitor_instance_names.("SHARED") do
        last_observed_time = Map.get(state.instance_times, instance_name, state.start_time)
        age = NaiveDateTime.diff(clock.(), last_observed_time, :second)
        {instance_name, age}
      end

    {:reply, reply, state}
  end

  defp monitor_key(event_or_config), do: event_or_config.monitor_logical_name
  defp instance_key(event), do: event.instance_name
end
