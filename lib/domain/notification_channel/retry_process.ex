defmodule Domain.NotificationChannel.RetryProcess do
  @moduledoc """
  This ProcessManager is responsible for scheduling notification delivery and
  retries. It lives as long as there is something to be delivered. A table
  of all active retry processes is kept in the projections database so we
  can fan out ClockTicked events.

  This ProcessManager is tied to the hip with the NotificationChannel.

  Implementation note: state changes and actions are separated in a process manager,
  which may make things a bit harder to read. Try to keep pairs of `handle` and `apply`
  methods in the same shape as much as possible so it makes things easier to follow.
  """

  # This process manager has a couple non-pure functions: the fan-out of the
  # clock tick and the registration and de-registration. It's a necessary
  # evil to have fan-out in Commanded. Check references to Backend.Projections
  # for these bits.

  use Commanded.ProcessManagers.ProcessManager,
    application: Backend.App,
    name: __MODULE__,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ],
    idle_timeout: :timer.minutes(60)

  use TypedStruct
  alias Domain.NotificationChannel.{Commands, Events}
  require Logger

  @type notification :: %{
          alert_id: String.t(),
          tries_left: non_neg_integer()
        }
  @clock_name Backend.MinuteClock.name()
  # Once per minute, so we drop after around five minutes.
  @try_count 5

  typedstruct do
    field :id, String.t()
    field :account_id, String.t()

    # If we have a current notification, we're waiting for a result
    field :current_notification, notification() | nil, default: nil

    # Anything else is queued up and will come later.
    field :queued_notifications, [notification()], default: []

    # Serialization field so we can have nicer structs serialized
    field :x_val, any()
  end

  # We serialize in x_val so we can stash structs away.
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
    def decode(%{x_val: nil}), do: %Domain.NotificationChannel.RetryProcess{}

    def decode(value) do
      :erlang.binary_to_term(Base.decode64!(value.x_val))
    end
  end

  @impl true
  def interested?(e = %Events.Created{}), do: {:start, e.id}
  def interested?(e = %Events.NotificationQueued{}), do: {:continue, e.id}
  def interested?(e = %Events.DeliveryCompleted{}), do: {:continue, e.id}
  def interested?(e = %Events.RetryScheduled{}), do: {:continue, e.id}

  def interested?(%Domain.Clock.Ticked{id: @clock_name}) do
    {:continue, Backend.Projections.NotificationChannel.RetryProcess.all_ids()}
  end

  # Event handling

  @impl true
  def handle(retry_proc, e = %Events.NotificationQueued{}) do
    if is_nil(retry_proc.current_notification) and retry_proc.queued_notifications == [] do
      dispatch(retry_proc, e)
    end
  end

  def handle(retry_proc, e = %Events.DeliveryCompleted{}) do
    Logger.info("RetryProcess for #{retry_proc.id} completed alert #{e.alert_id}")
    # If something is in the queue, run it right away
    case retry_proc.queued_notifications do
      [notification | _] ->
        dispatch(retry_proc, notification)

      _ ->
        nil
    end
  end

  def handle(retry_proc, e = %Events.RetryScheduled{}) do
    Logger.info("RetryProcess for #{retry_proc.id} need retry alert #{e.alert_id}")

    case Map.get(retry_proc, :current_notification) do
      nil ->
        # Got into a bad state, attempting to retry with no current notification. Just ignore it
        nil
      %{alert_id: alert_id, tries_left: 0} ->
        # This one fails, so we fail it
        # We could immediately kick some work off, but given that the channel
        # apparently has problems, it is better to wait so we do nothing else.
        %Commands.FailDelivery{id: retry_proc.id, alert_id: alert_id}
      _ ->
        nil
    end
  end

  def handle(retry_proc, %Domain.Clock.Ticked{}) do
    Logger.debug("RetryProcess for #{retry_proc.id} clock ticked")
    # If we have a current notification, do nothing, we're waiting for some response
    # (DeliveryCompleted or RetryScheduled). Else, we try the next delivery if something
    # is queued.
    if is_nil(retry_proc.current_notification) do
      case retry_proc.queued_notifications do
        [next | _rest] ->
          dispatch(retry_proc, next)

        [] ->
          # No scheduled and no in-flight notification, so we can deregister for now
          deregister(retry_proc)
          nil
      end
    end
  end

  # State management

  @impl true
  def apply(retry_proc, e = %Events.Created{}) do
    %__MODULE__{retry_proc | id: e.id}
  end

  def apply(retry_proc, e = %Events.NotificationQueued{}) do
    if is_nil(retry_proc.current_notification) and retry_proc.queued_notifications == [] do
      # Nothing in progress or queued, so this is the current notification
      %__MODULE__{retry_proc | current_notification: make_notification(e)}
    else
      # Something in progress, put it at the end of the queue
      %__MODULE__{
        retry_proc
        | queued_notifications: retry_proc.queued_notifications ++ [make_notification(e)]
      }
    end
  end

  def apply(retry_proc, %Events.DeliveryCompleted{}) do
    case retry_proc.queued_notifications do
      [notification | rest] ->
        %__MODULE__{retry_proc | current_notification: notification, queued_notifications: rest}

      [] ->
        %__MODULE__{retry_proc | current_notification: nil}
    end
  end

  def apply(retry_proc, %Events.RetryScheduled{}) do
    case Map.get(retry_proc, :current_notification) do
      nil ->
        # Trying to retry with no current notification. Do nothing
        retry_proc
      %{tries_left: 0} ->
        # Give up, on the next tick we'll try the next queued one.
        %__MODULE__{retry_proc | current_notification: nil}
      current ->
        # Count down, on the next clock tick we'll try again.
        %__MODULE__{
          retry_proc
          | current_notification: nil,
            queued_notifications: [
              countdown(current)
              | retry_proc.queued_notifications
            ]
        }
    end
  end

  def apply(retry_proc, %Domain.Clock.Ticked{}) do
    if is_nil(retry_proc.current_notification) do
      case retry_proc.queued_notifications do
        [next | rest] ->
          %__MODULE__{retry_proc | current_notification: next, queued_notifications: rest}

        _ ->
          retry_proc
      end
    else
      retry_proc
    end
  end

  # Helpers

  defp dispatch(retry_proc, queued_or_event) do
    Logger.info("RetryProcess for #{retry_proc.id} dispatching alert #{queued_or_event.alert_id}")
    # However we dispatch, we need to be registered for clock ticks. Registration is
    # idempotent so we always call it when we dispatch something.
    register(retry_proc)

    %Commands.AttemptDelivery{
      id: retry_proc.id,
      alert_id: queued_or_event.alert_id,
      subscription_id: queued_or_event.subscription_id
    }
  end

  defp make_notification(evt), do: %{alert_id: evt.alert_id, subscription_id: evt.subscription_id, tries_left: @try_count}

  defp countdown(queued_notification),
    do: %{alert_id: queued_notification.alert_id, subscription_id: queued_notification.subscription_id, tries_left: queued_notification.tries_left - 1}

  # Registration and de-registration calls for retry processes. Whenever something is in
  # flight, we want to hear the clock ticking, but otherwise we're not interested.
  if Mix.env() == :test do

    # We don't have a DB in test so we don't want to bother with this.
    require Logger
    def register(retry_proc),
      do: Logger.info("Register retry process with id #{retry_proc.id}")
    def deregister(retry_proc),
      do: Logger.info("Deregister retry process with id #{retry_proc.id}")
  else

    def register(retry_proc) do
      Logger.info("Register retry process with id #{retry_proc.id}")
      Backend.Projections.NotificationChannel.RetryProcess.register(retry_proc.id)
    end
    def deregister(retry_proc) do
      Logger.info("Deregister retry process with id #{retry_proc.id}")
      Backend.Projections.NotificationChannel.RetryProcess.deregister(retry_proc.id)
    end

  end
end
