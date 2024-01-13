defmodule Domain.Clock do
  @moduledoc """
  A clock aggregate root.

  This module helps modelling time and timeouts. A process should be started at startup that drives the
  clock every <period> seconds, and once that happens, the clock will start ticking. The clock does
  not really have an idea of wall clock time, it only deals with numbers since an epoch - the idea
  is that Process Managers will hook into Ticked events and interpret these.

  Clock commands are idempotent, which means that an application may start multiple "tickers" to drive the
  clock.

  Because it is a simple and limited module, we include the command and event here directly.
  """

  use TypedStruct

  typedstruct module: Tick, enforce: true do
    @moduledoc """
    Instruct the clock to advance. If the value is new, the clock will emit a `Ticked` event.
    """
    field :id, String.t
    field :value, integer()
  end

  typedstruct module: Ticked, enforce: true do
    @moduledoc """
    Indicates that the corresponding clock moved forward.
    """
    plugin Backend.JsonUtils
    field :id, String.t
    field :value, integer()
  end

  defstruct [
    :id,
    :value
  ]

  def execute(clock, c = %Tick{}) do
    # We don't have an explicit create command for now
    cond do
      is_nil(clock.id) ->
        %Ticked{id: c.id, value: c.value}
      c.value > clock.value ->
        %Ticked{id: clock.id, value: c.value}
      true ->
        # We've already seen this "tick"
        nil
    end
  end

  def apply(clock, e = %Ticked{}) do
    %__MODULE__{
      id: clock.id || e.id,
      value: e.value
    }
  end
end
