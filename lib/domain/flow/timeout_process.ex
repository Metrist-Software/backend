defmodule Domain.Flow.TimeoutProcess do
  @moduledoc """
  This is a process manager that pretty much always has a single active
  process - it hooks into the minute clock ticks and into the relevant
  flow events to figure out when flow instances should time out.

  Ideally, we would have a process instance per flow, but the issue is that
  process managers do not have (easy) access to the active instances, we would
  need to fan out clock ticks, and so on. Given that we will not have _that_
  many concurrent flows active, it's simpler to have a single instance that
  just monitors all the flows.
  """

  # Note that this code has backend dependencies but still feels like it should
  # belong in the Domain bit. We opted to keep it in Domain for now.

  use Commanded.ProcessManagers.ProcessManager,
    application: Backend.App,
    name: __MODULE__

  use TypedStruct

  @instance_id __MODULE__.TheInstance
  @clock_name Backend.MinuteClock.name()

  typedstruct do
    plugin(Backend.JsonUtils)
    field :entries, %{String.t() => pos_integer()}, default: %{}
  end

  # This is the stuff we are interested in.
  def interested?(%Domain.Clock.Ticked{id: @clock_name}), do: {:start, @instance_id}
  def interested?(%Domain.Flow.Events.Created{}), do: {:start, @instance_id}
  def interested?(%Domain.Flow.Events.FlowCompleted{}), do: {:start, @instance_id}

  # On every minute tick, emit timeouts for those flows that are too old
  def handle(pm, %Domain.Clock.Ticked{id: @clock_name, value: ticks}) do
    pm.entries
    |> Enum.filter(fn {_i, t} -> t <= ticks end)
    |> Enum.map(fn {i, _t} ->
      if is_atom(i) do
        %Domain.Flow.Commands.Timeout{id: Atom.to_string(i)}
      else
        %Domain.Flow.Commands.Timeout{id: i}
      end
    end)
  end

  # When a flow has been created, start the timeout timer
  def apply(pm, %Domain.Flow.Events.Created{id: id, timeout_minute: timeout_minute}) do
    %__MODULE__{pm | entries: Map.put(pm.entries, id, timeout_minute)}
  end

  # When a flow completes, remove it from our list. Note that when a flow
  # times out, we are the cause of that so it already is gone.
  def apply(pm, %Domain.Flow.Events.FlowCompleted{id: id}) do
    %__MODULE__{pm | entries: Map.delete(pm.entries, id)}
  end

  # On timeout, keep only the entries that did not timeout
  def apply(pm, %Domain.Clock.Ticked{id: @clock_name, value: ticks}) do
    new_entries =
      pm.entries
      |> Enum.reject(fn {_i, t} -> t <= ticks end)
      |> Map.new()
    %__MODULE__{pm | entries: new_entries}
  end
end
