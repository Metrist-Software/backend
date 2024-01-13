defmodule Backend.EventStoreRewriter.Migration do
  @type event :: EventStore.RecordedEvent.t()
  @type state :: map()
  @type state_key :: any()
  @type state_value :: any()

  @doc """
  Code to determine what to do with individual events

  Should return a tuple containing a list of events that the given event should
  map to and the updated persistent state to use across the run

  Returning an empty list of events will drop the event altogether
  """
  @callback handle_event(event(), state()) :: {list(event()), state()}

  @doc """
  Called at the end of the stream transform on each key-value pair in the final
  migration state

  Should return a list of any additional events that ar to be added to the end
  of the event stream
  """
  @callback handle_last(state_key(), state_value()) :: list(event())

  @doc """
  The Commanded application that this migration is operating on
  """
  @callback app() :: atom()

  @doc """
  The name of this migration.
  """
  @callback name() :: atom()

  @doc """
  Ths schema name where this migration will write
  """
  @callback schema() :: String.t()

  @doc """
  The event store this migration uses. Obtained through the app settings
  """
  @callback event_store() :: atom()

  @doc """
  Called after appending all events of a batch to the stream, using the same
  transaction. Allows for any additional processing that may be required, for
  example linking events to other streams.

  Note that EventStore functions ran should pass explicit :name and :conn options
  using `migration.name()` and `conn` from the arguments passed to the function (not
  directly from the module itself to make testing easier). Similarly, the event store itself
  should be obtained from `migration.event_store()`.
  """
  @callback after_append_batch_to_stream(list(event()), atom(), Postgrex.conn()) :: any()

  @optional_callbacks after_append_batch_to_stream: 3

  defmacro __using__(opts) do
    app =
      case Keyword.get(opts, :app) do
        nil -> raise "Missing required value for :app"
        app -> app
      end

    name =
      case Keyword.get(opts, :name) do
        name when is_binary(name) -> String.to_atom(name)
        name when is_atom(name) -> name
        name -> raise "Invalid value for :name. Expected String or Atom, got: #{inspect(name)}"
      end

    schema = Atom.to_string(name)

    quote location: :keep do
      @before_compile unquote(__MODULE__)
      @behaviour Backend.EventStoreRewriter.Migration

      import Backend.EventStoreRewriter.Migration

      @impl true
      def schema(), do: unquote(schema)
      @impl true
      def name(), do: unquote(name)
      @impl true
      def app(), do: unquote(app)
      @impl true
      def event_store(), do: unquote(app).config()[:event_store][:event_store]
    end
  end

  defmacro __before_compile__(_env) do
    # Include default `handle_event/2` and `handle_last/2` callback functions in module
    quote generated: true do
      @doc false
      @impl true
      def handle_event(event, state) do
        {[event], state}
      end

      @doc false
      @impl true
      def handle_last(_k, _v), do: []
    end
  end

  @doc """
  Drops all events of a given type
  """
  defmacro drop(type) do
    quote do
      def handle_event(%{data: %unquote(type){}}, state), do: {[], state}
    end
  end

  @doc """
  Drops all events of a given type that pass the given condition
  """
  defmacro drop(type, condition_fnc) do
    quote do
      def handle_event(%{data: %unquote(type){}} = re, state) do
        if unquote(condition_fnc).(re, state) do
          {[], state}
        else
          {[re], state}
        end
      end
    end
  end
end
