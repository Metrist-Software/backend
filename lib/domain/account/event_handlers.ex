defmodule Domain.Account.EventHandlers do
  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  require Logger

  # NOTE: all commands emitted here must have idempotency checks in the
  # aggregate root!

  @impl true
  def handle(e = %Domain.Account.Events.UserAdded{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    cmd = %Domain.User.Commands.Update{
      id: e.user_id,
      user_account_id: e.id
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id,
      metadata: %{actor: Backend.Auth.Actor.backend_code()})
    :ok
  end

  def handle(e = %Domain.Account.Events.UserRemoved{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    cmd = %Domain.User.Commands.Update{
      id: e.user_id,
      user_account_id: nil
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id,
      metadata: %{actor: Backend.Auth.Actor.backend_code()})
    :ok
  end

  def handle(e = %Domain.Account.Events.MonitorAdded{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    id = Backend.Projections.construct_monitor_root_aggregate_id(e.id, e.logical_name)

    cmd = %Domain.Monitor.Commands.Create{
      id: id,
      monitor_logical_name: e.logical_name,
      name: e.name,
      account_id: e.id
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id)
    cmd = %Domain.Monitor.Commands.AddAnalyzerConfig{
      id: id,
      default_degraded_threshold: e.default_degraded_threshold,
      instances: e.instances,
      check_configs: e.check_configs
    }
    Backend.App.dispatch(cmd,
        causation_id: causation_id,
        correlation_id: correlation_id,
        metadata: %{actor: Backend.Auth.Actor.backend_code()})
    :ok
  end

  def handle(e = %Domain.Account.Events.MonitorRemoved{}, %{event_id: causation_id, correlation_id: correlation_id}) do
    id = Backend.Projections.construct_monitor_root_aggregate_id(e.id, e.logical_name)
    cmd = %Domain.Monitor.Commands.Reset{
      id: id
    }
    Backend.App.dispatch(cmd,
      causation_id: causation_id,
      correlation_id: correlation_id,
      metadata: %{actor: Backend.Auth.Actor.backend_code()})
    :ok
  end
end
