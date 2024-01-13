# Possible optimization: Use a new typed_handler macro to
# subscribe to just what we need
# See Backend.Projectors.TypeStreamLinker.Helpers
defmodule Backend.RealTimeAnalytics.EventHandlers do
  require Logger

  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  @impl true
  def handle(e = %Domain.Account.Events.MonitorRemoved{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.remove_config(e.id, e.logical_name)
    :ok
  end

  def handle(e = %Domain.Monitor.Events.TelemetryAdded{}, _metadata) do
    Backend.RealTimeAnalytics.SwarmSupervisor.dispatch_telemetry(e)
    :ok
  end

  def handle(e = %Domain.Monitor.Events.ErrorAdded{}, _metadata) do
    Backend.RealTimeAnalytics.SwarmSupervisor.dispatch_error(e)
    :ok
  end

  def handle(e = %Domain.Monitor.Events.AnalyzerConfigAdded{}, _metadata) do
    monitor =  %Backend.Projections.Dbpa.Monitor{
      name: e.monitor_name || e.monitor_logical_name,
      logical_name: e.monitor_logical_name,
      checks: [],
      monitor_configs: [],
      inserted_at: NaiveDateTime.utc_now()
    }

    Backend.RealTimeAnalytics.Loader.load_and_start_analysis(
      e.account_id,
      monitor,
      Backend.Projections.Dbpa.AnalyzerConfig.from_event(e)
    )
    :ok
  end

  def handle(e = %Domain.Monitor.Events.AnalyzerConfigUpdated{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.update_config(
      e.account_id,
      e.monitor_logical_name,
      Backend.Projections.Dbpa.AnalyzerConfig.from_event(e)
    )
    :ok
  end

  def handle(e = %Domain.Monitor.Events.CheckAdded{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.add_check(
      e.account_id,
      e.monitor_logical_name,
      e.name,
      e.logical_name
    )
    :ok
  end

  def handle(e = %Domain.Monitor.Events.CheckRemoved{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.remove_check(
      e.account_id,
      e.monitor_logical_name,
      e.check_logical_name
    )
    :ok
  end

  def handle(e = %Domain.Monitor.Events.CheckNameUpdated{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.update_check(
      e.account_id,
      e.monitor_logical_name,
      e.name,
      e.logical_name
    )
    :ok
  end

  def handle(e = %Domain.Monitor.Events.AnalyzerConfigRemoved{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.remove_config(e.account_id, e.monitor_logical_name)
    :ok
  end

  def handle(e = %Domain.Monitor.Events.StepsSet{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.set_steps(
      e.account_id,
      e.monitor_logical_name,
      Enum.map(e.steps, &(&1.check_logical_name))
    )
    :ok
  end

  def handle(e = %Domain.Monitor.Events.ConfigAdded{}, _metadata) do
    Backend.RealTimeAnalytics.Analysis.set_steps(
      e.account_id,
      e.monitor_logical_name,
      Enum.map(e.steps, &(&1.check_logical_name))
    )
    :ok
  end
end
