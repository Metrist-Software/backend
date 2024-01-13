defmodule Domain.Account.AlertManager do
  @moduledoc """
  This ProcesseManager is responsible for listening to AlertAdded events and emitting DispatchAlert or DropAlert
  commands when appropriate.

  One process manager is instance is started per account.

  This process manager never issues a :stop as the single instance per account can live indefinitely

  Process Logic:

  Instance specific alerts are not batched and the DispatchAlert is sent immediately.

  Non instance specific alerts will batch up alerts for a minimum of @minimum_batch_delay and a maximum of approx. 89s.
  A new alert generated for the same state simply overwrite the previous one as it will include all relevant details
  including the details from the previous alert within it. An alert with a different state than the currently queued
  version will cause the currently queued version to dispatch immediately and the new alert with the different state will
  queue up as normal.

  This ProcessManager will not issue a DispatchAlert command if the generated_at of the alert is older than 5 minutes
  """

  use Commanded.ProcessManagers.ProcessManager,
    application: Backend.App,
    name: __MODULE__,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  alias Domain.Account.Commands.{DispatchAlert, DropAlert}
  alias Domain.Account.Events.AlertAdded
  alias Domain.Clock.Ticked

  use TypedStruct
  require Logger

  @type queued_alert :: %{alert: AlertAdded.t(), timeout: integer()}
  @clock_name Backend.MinuteClock.name()
  @minimum_batch_delay 30

  typedstruct do
    field :monitor_alerts, %{binary() => queued_alert()}, default: %{}
    field :x_val, any()
  end

  # We're going to binary serialize this as structs are involved
  defimpl Jason.Encoder do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          "x_val" => Base.encode64(:erlang.term_to_binary(value))
        },
        opts
      )
    end
  end

  defimpl Commanded.Serialization.JsonDecoder do
    def decode(%{ x_val: nil }), do: %Domain.Account.AlertManager{}
    def decode(value) do
      :erlang.binary_to_term(Base.decode64!(value.x_val))
    end
  end

  @impl true
  def interested?(%AlertAdded{id: id}), do: {:start, id}
  def interested?(%Ticked{id: @clock_name}) do
    # Smells here because we need all the account IDs to :continue those on tick in case of a restart.
    # There isn't really a way to get that from the Domain side so going to Backend here.
    # Commanded won't restart a process manager instance until it sees an explicit :start or :continue
    # response from interested? with an actual instance ID. At that point it will start the ProcessManagerInstance
    # and read the state. It does not restart process manager instances when the ProcessRouter starts up unfortunately.
    # There also isn't some type of "init" function that can change accessible state to pass it in that way.
    # init/1 exist but won't do what we need (see https://hexdocs.pm/commanded/Commanded.ProcessManagers.ProcessManager.html#c:init/1)

    # This means a query to our public.Accounts database once a minute. Some type of
    # intermediate caching system seems like overkill here and we could abstract this to another module
    # which can be passed different query/load functions but again likely overkill.

    # Other option is a clock per process manager instance which would work fine but with 1_000
    # accounts would mean 1.4 million tick events per day.

    # Going with lesser of 2 evils here.

    # Still keeping this process manager on the domain side as it's all domain/business logic below.
    account_ids =
      Backend.Projections.list_accounts()
      |> Enum.map(&(&1.id))

    {:continue, account_ids}
  end

  @impl true
  def handle(_state, %AlertAdded{ is_instance_specific: true } = e) do
    maybe_dispatch_alert(e)
  end

  def handle(state, %AlertAdded{ is_instance_specific: false } = e) do
    case Map.get(state.monitor_alerts, e.monitor_logical_name) do
      %{alert: existing_alert} ->
        if existing_alert.state != e.state do
          maybe_dispatch_alert(existing_alert)
        else
          # Record drop for previous alert w/ same state
          %DropAlert{id: e.id, alert_id: existing_alert.alert_id, reason: :batching_replaced}
        end
      nil ->
        Logger.debug("Didn't find existing alert for AlertAdded with id #{inspect e.id}")
        nil
    end
  end

  def handle(state, %Domain.Clock.Ticked{id: @clock_name, value: ticks}) do
    # Dispatch anything that's due
    state.monitor_alerts
    |> Enum.filter(fn {_monitor_logical_name, %{ timeout: timeout}} -> timeout <= ticks end)
    |> Enum.map(fn {_mln, %{ alert: alert }} -> maybe_dispatch_alert(alert) end)
    |> Enum.reject(&is_nil(&1))
  end

  @impl true
  def apply(state, %AlertAdded{ is_instance_specific: true }) do
    # we don't have to do anything here
    # we already dispatched this alert and we don't want to enqueue it
    state
  end

  def apply(state, %AlertAdded{ is_instance_specific: false } = e) do
    # Always update the state map as we would have already sent the previous alert in the handle/2 if needed
    # for a state change. Only question is whether or not we keep the existing or set a new timeout

    new_timeout = Backend.MinuteClock.plus(@minimum_batch_delay, :seconds)

    timeout =
      case Map.get(state.monitor_alerts, e.monitor_logical_name) do
        nil ->
          new_timeout
        %{alert: existing_alert, timeout: existing_timeout} ->
          if existing_alert.state != e.state do
            new_timeout
          else
            existing_timeout
          end
        end

    %__MODULE__{ state | monitor_alerts: Map.put(state.monitor_alerts, e.monitor_logical_name, %{ alert: e, timeout: timeout})}
  end

  def apply(state, %Domain.Clock.Ticked{id: @clock_name, value: ticks}) do
    updated_list =
      state.monitor_alerts
      |> Enum.reject(fn {_i, %{ timeout: t }} -> t <= ticks end)
      |> Map.new()
    %__MODULE__{ state | monitor_alerts: updated_list }
  end

  defp maybe_dispatch_alert(%AlertAdded{} = e) do
    # Transform the AlertAdded back to a Commands.Alert struct
    # Pretty much the opposite of make_event and Map.put(:id, c.id)
    # Instead of rebuilding it
    alert =
      e
      |> Map.put(:__struct__, Domain.Account.Commands.Alert)
      |> Map.delete(:id)

    # If this process manager tries to dispatch an alert that is more than 5m old, it is dropped
    if alert_not_older_than_5_minutes?(e) do
      %DispatchAlert{id: e.id, alert: alert}
    else
      # Record drop for timed out alert
      %DropAlert{id: e.id, alert_id: alert.alert_id, reason: :too_old}
    end
  end

  defp alert_not_older_than_5_minutes?(%AlertAdded{ generated_at: generated_at }) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), generated_at, :second) < (5*60)
  end
end
