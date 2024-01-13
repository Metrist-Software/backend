defmodule Backend.JsonUtils do
  @moduledoc """
  Utilities for most common JSON issues we encounter.
  """

  use TypedStruct.Plugin

  @impl true
  defmacro init(_opts) do
    quote do
      @derive Jason.Encoder
      Module.register_attribute(__MODULE__, :dt_fields, accumulate: true)
    end
  end

  @impl true
  def field(name, type, _opts, _env) do
    # The type is a bit convoluted here as we get the AST definition for the type,
    # so the easiest way out is just to let the Macro module convert it back.
    if Macro.to_string(type) == "NaiveDateTime.t()" do
      quote do
        @dt_fields unquote(name)
      end
    end
    #IO.puts("field(#{inspect name}, #{inspect type}, #{inspect opts})")
  end

  @impl true
  def after_definition(_opts) do
    quote location: :keep do
      if @dt_fields != [] do
        def __dt_fields__, do: @dt_fields
        @after_compile {Backend.JsonUtils, :__gen_decoder__}
      end
    end
  end

  @doc """
  Called when we detected NaiveDateTime fields so we can generate a JsonDecoder
  implementation.
  """
  def __gen_decoder__(env, _bytecode) do
    mod = env.module
    newmod = String.to_atom("#{mod}.__Decoder__")
    fields = apply(mod, :__dt_fields__, [])
    code = quote do
      defimpl Commanded.Serialization.JsonDecoder, for: unquote(mod) do
        def decode(s = %unquote(mod){}) do
          # Exercise for the reader: unroll this loop. I doubt whether we'll see the
          # performance difference, though.
          Enum.reduce(unquote(fields), s, fn field, s ->
            Map.put(s, field, Backend.JsonUtils.maybe_time_from(Map.get(s, field)))
          end)
        end
      end
    end
    Module.create(newmod, code, Macro.Env.location(__ENV__))
  end

  @doc """
  Parse a string as NaiveDateTime or nil.
  """
  def maybe_time_from(nil), do: nil
  def maybe_time_from(string) do
    case NaiveDateTime.from_iso8601(string) do
      {:ok, value} -> value
      _ -> nil
    end
  end
end
