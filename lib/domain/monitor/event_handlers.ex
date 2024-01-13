defmodule Domain.Monitor.EventHandlers do
  require Logger

  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  # NOTE: all commands emitted here must have idempotency checks in the
  # aggregate root!

  @impl true
  def handle(e = %Domain.Monitor.Events.Created{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    cmd = %Domain.Account.Commands.AddMonitor{
      id: e.account_id,
      logical_name: e.monitor_logical_name,
      name: Backend.Docs.Generated.Monitors.name(e.monitor_logical_name) || e.monitor_logical_name,
      default_degraded_threshold: 5.0,
      instances: [],
      check_configs: []
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id,
      metadata: %{actor: Backend.Auth.Actor.backend_code()})
    :ok
  end

  def handle(e = %Domain.Monitor.Events.InstanceAdded{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    # Keep account-level instances in sync.
    cmd = %Domain.Account.Commands.AddInstance{
      id: e.account_id,
      instance_name: e.instance_name
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id,
      metadata: %{actor: Backend.Auth.Actor.backend_code()})
    :ok
  end
end
