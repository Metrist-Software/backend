defmodule Backend.Projectors.TypeStreamLinker do
  @moduledoc """
  This projector will link events into their own typed streams. This
  way we can easily find back all events of a certain kind in case we
  want to do analysis on them.
  """
  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    subscription_opts: [
      buffer_size: 1000,
      checkpoint_threshold: 1000
    ]

  @impl true
  def handle(%event_type{}, metadata) do
    event_type
    |> event_type_to_stream()
    |> link_to_stream(metadata)

    :ok
  end

  @doc """
  Generate type stream name from event type. The name is make "absolute", as all
  type symbols by the time they hit beam start with "Elixir". Depending on how we
  are called we may see different names but we take care to make all typestream
  names start with the same thing.
  """
  def event_type_to_stream(mod = {:__aliases__, _, _}) do
    event_type_to_stream(Macro.to_string(mod))
  end

  def event_type_to_stream(event_type) do
    case "#{event_type}" do
      <<"Elixir.", _rest::binary>> ->
        "TypeStream.#{event_type}"
      _ ->
        "TypeStream.Elixir.#{event_type}"
    end
  end

  defp link_to_stream(stream_name, %{event_id: event_id}) do
    Backend.EventStore.link_to_stream(stream_name, :any_version, [event_id])
  end

  defmodule Helpers do
    @moduledoc """
    Helpers to facilitate using typestream linking. Basically this exports some code
    that makes it very easy to have projections running on type streams. Needs to
    be included through `use`.

    Using this module exports a `children/0` function which can be used to get a list
    of children to pass to a supervisor for startup.
    """

    defmacro __using__(_opts) do
      quote location: :keep do
        import unquote(__MODULE__)

        Module.register_attribute(__MODULE__, :__ts_projectors, accumulate: true)
        @before_compile {unquote(__MODULE__), :before_compile}
      end
    end

    defmacro before_compile(_env) do
      quote do
        def children, do: @__ts_projectors
      end
    end

    # Note: these macros aren't trivial, and care needs to be taken when changing them. The
    # simplest approach is to change `typed_event_handler` first, because you can actually
    # decompile the generated module and have something sensible. Then apply the same changes
    # to the Ecto version (which also can be decompiled, but it is much harder to check because
    # there's a lot of code).

    @doc """
    Wrapper around Ecto projections for type stream handlers that project
    to Ecto. This expands to a full Commanded Ecto projection module that
    "listens" to a single TypeStream.
    """
    defmacro typed_ecto_handler(event_type, handler_fun) do
      quote location: :keep do
        import Backend.Projectors.TypeStreamLinker.Helpers

        @__ts_projectors full_type(unquote(__CALLER__.module), unquote(event_type))
        defmodule full_type(unquote(__CALLER__.module), unquote(event_type)) do
          use Commanded.Projections.Ecto,
            application: Backend.App,
            name: __MODULE__,
            repo: Backend.Repo,
            subscribe_to: type_stream(unquote(event_type))

          project(event, _metadata, fn multi ->
            unquote(handler_fun).(multi, event)
          end)
        end
      end
    end

    @doc """
    Macro for regular type stream event handlers. This expands to a full Commanded event handler
    module that "listens" to a single TypeStream.
    """
    defmacro typed_event_handler(event_type, handler_fun) do
      quote location: :keep do
        import Backend.Projectors.TypeStreamLinker.Helpers

        @__ts_projectors full_type(unquote(__CALLER__.module), unquote(event_type))
        defmodule full_type(unquote(__CALLER__.module), unquote(event_type)) do
          use Commanded.Event.Handler,
            application: Backend.App,
            name: __MODULE__,
            subscribe_to: type_stream(unquote(event_type))

          @impl true
          def handle(event, metadata) do
            unquote(handler_fun).(event, metadata)
          end
        end
      end
    end

    # Shorthand to get the type stream from an event type so we can keep the macro code shorter
    def type_stream(event_type),
      do: Backend.Projectors.TypeStreamLinker.event_type_to_stream(event_type)

    # Shorthand to get the full module type from caller and event type.
    def full_type(caller, event_type),
      do: Module.concat(caller, Macro.to_string(event_type))
  end
end
