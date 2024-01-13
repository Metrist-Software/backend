defmodule Backend.PubSub do
  @moduledoc """
  Module to keep all PubSub stuff together.
  """

  defmodule DelayingSupervisor do
     use Supervisor
     require Logger

     def start_link(opts) do
        Logger.info("Delaying PubSub start by 50ms to release name registration")
        Process.sleep(50)
        Phoenix.PubSub.Supervisor.start_link(opts)
     end

     defdelegate init(opts), to: Phoenix.PubSub.Supervisor
  end

  def spec, do: {DelayingSupervisor, name: __MODULE__}

  def broadcast!(topic, message),
    do: Phoenix.PubSub.broadcast!(__MODULE__, topic, message)

  def broadcast(topic, message),
    do: Phoenix.PubSub.broadcast(__MODULE__, topic, message)

  def subscribe(topic, opts \\ []) do
     Phoenix.PubSub.subscribe(__MODULE__, topic, opts)
  end

  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(__MODULE__, topic)
 end

  @spec broadcast_to_topic_of!(
          atom
          | %{
              :__struct__ =>
                atom
                | %{
                    :__struct__ => atom | %{:__struct__ => atom | map, optional(any) => any},
                    optional(any) => any
                  },
              :id => any,
              optional(any) => any
            },
          any
        ) :: :ok
  def broadcast_to_topic_of!(event_or_command, message),
    do: broadcast!(topic_of(event_or_command), message)

  def broadcast_to_topic_of(event_or_command, message),
    do: broadcast(topic_of(event_or_command), message)

  def subscribe_to_topic_of(event_or_command, opts \\ []),
    do: subscribe(topic_of(event_or_command), opts)

  def unsubscribe_to_topic_of(event_or_command),
    do: unsubscribe(topic_of(event_or_command))

  @doc """
  Given an event or command, return the topic.
  """
  def topic_of(event_or_command) do
    entity_name = Domain.Helpers.entity_of(event_or_command)
    id = event_or_command.id
    topic_of(entity_name, id)
  end

  @doc """
  Given an entity name string or module and an id, return the topic.
  """
  def topic_of(entity_name, id) when is_binary(entity_name) do
     "#{entity_name}:#{id}"
  end
  def topic_of(entity, id) when is_atom(entity) do
     topic_of(Domain.Helpers.entity_of(entity), id)
  end

  def broadcast_rta_monitor_change({account_id, monitor_logical_name, _check, _instance} = mci, pid) do
    Phoenix.PubSub.broadcast!(__MODULE__, "rta:#{account_id}:#{monitor_logical_name}", %{mci: mci, pid: pid})
  end

  def subscribe_rta_monitor_changes(account_id, monitor_logical_name, opts \\ []) do
    # Make sure we never double subscribe. unsubscribe always returns :ok
    Phoenix.PubSub.unsubscribe(__MODULE__, "rta:#{account_id}:#{monitor_logical_name}")
    Phoenix.PubSub.subscribe(__MODULE__, "rta:#{account_id}:#{monitor_logical_name}", opts)
  end

  def subscribe_snapshot_state_changed(account_id, monitor_logical_name, opts \\ []) do
    Phoenix.PubSub.unsubscribe(__MODULE__, "snapshot_state_changed:#{account_id}:#{monitor_logical_name}")
    Phoenix.PubSub.subscribe(__MODULE__, "snapshot_state_changed:#{account_id}:#{monitor_logical_name}", opts)
  end
  def broadcast_snapshot_state_changed!(account_id, monitor_logical_name, monitor_state) do
    Phoenix.PubSub.broadcast!(__MODULE__, "snapshot_state_changed:#{account_id}:#{monitor_logical_name}", {:snapshot_state_changed, account_id, monitor_logical_name, monitor_state })
  end

  def subscribe_status_page_created(opts \\ []) do
    Phoenix.PubSub.unsubscribe(__MODULE__, "status_page_created")
    Phoenix.PubSub.subscribe(__MODULE__, "status_page_created", opts)
  end

  def broadcast_status_page_created!(status_page_id) do
    Phoenix.PubSub.broadcast!(__MODULE__, "status_page_created", {:status_page_created, status_page_id})
  end
end
