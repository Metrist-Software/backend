defmodule BackendWeb.Telemetry do
  use Supervisor
  require Logger
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    children =
      case Application.get_env(:backend, :metrics_reporting_module) do
        nil ->
          Logger.info("No metrics module specified")
          children
        mod ->
          Logger.info("Sending metrics using #{inspect mod}")
          children ++ [{mod, metrics: metrics()}]
      end


    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Metrics (names of events) we want to report to whatever we have configured as
  reporting module.
  """
  def metrics() do
    import Telemetry.Metrics
    in_ms = [unit: {:native, :millisecond}]
    in_ms_tagged = &(Keyword.put(in_ms, :tags, &1))
    [
      # Phoenix Metrics
      counter("phoenix.endpoint.stop.duration",
        in_ms_tagged.([:status, :request_path])),
      summary("phoenix.endpoint.stop.duration",
        in_ms_tagged.([:status, :request_path])),

      # That's also in the above, but it doesn't harm to have this seperately
      counter("phoenix.error_rendered.duration", tags: [:status]),

      # Database Metrics
      counter("backend.repo.query.total_time"),
      summary("backend.repo.query.total_time", in_ms),
      summary("backend.repo.query.decode_time", in_ms),
      summary("backend.repo.query.query_time", in_ms),
      summary("backend.repo.query.queue_time", in_ms),
      summary("backend.repo.query.idle_time", in_ms),
      counter("backend.telemetry_repo.query.total_time"),
      summary("backend.telemetry_repo.query.total_time", in_ms),
      summary("backend.telemetry_repo.query.decode_time", in_ms),
      summary("backend.telemetry_repo.query.query_time", in_ms),
      summary("backend.telemetry_repo.query.queue_time", in_ms),
      summary("backend.telemetry_repo.query.idle_time", in_ms),

      # VM Metrics
      summary("vm.memory.atom", unit: {:byte, :kilobyte}),
      summary("vm.memory.atom_used", unit: {:byte, :kilobyte}),
      summary("vm.memory.binary", unit: {:byte, :kilobyte}),
      summary("vm.memory.code", unit: {:byte, :kilobyte}),
      summary("vm.memory.ets", unit: {:byte, :kilobyte}),
      summary("vm.memory.processes", unit: {:byte, :kilobyte}),
      summary("vm.memory.processes_used", unit: {:byte, :kilobyte}),
      summary("vm.memory.system", unit: {:byte, :kilobyte}),
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      summary("vm.system_counts.atom_count"),
      summary("vm.system_counts.port_count"),
      summary("vm.system_counts.process_count")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {BackendWeb, :count_users, []}
    ]
  end
end
