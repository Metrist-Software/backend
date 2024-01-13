defmodule Domain.Flow do
  @moduledoc """
  A "flow" is a series of actions taken by a user that we find important enough
  to track to see whether any steps in there cause people to drop out of it.

  An example is the signup flow.
  """
  alias Domain.Flow.{Commands, Events}

  use TypedStruct

  typedstruct do
    field :id, String.t()
    # Steps in the flow
    field :steps, [String.t()]
    # The number of completed steps. Also can be interpreted as the index of the
    # next step we expect to be completed.
    field :completed, non_neg_integer()
  end

  def execute(%__MODULE__{id: nil}, c = %Commands.Create{}) do
    %Events.Created{
      id: c.id,
      name: c.name,
      timeout_minute: c.timeout_minute,
      steps: c.steps
    }
  end

  def execute(_flow, %Commands.Create{}), do: nil

  def execute(flow, c = %Commands.Step{}) do
    event =
      case Enum.find_index(flow.steps, &(&1 == c.step)) do
        nil ->
          nil

        step when step == flow.completed ->
          %Events.StepCompleted{id: flow.id, step: c.step, completed: flow.completed + 1}

        _other ->
          nil
      end

    # If this was the last step, we emit two events, one to indicate flow completion.
    case event do
      nil ->
        nil

      event when event.completed == length(flow.steps) ->
        [event, %Events.FlowCompleted{id: flow.id}]

      event ->
        event
    end
  end

  def execute(flow, %Commands.Timeout{}) do
    %Events.FlowTimedOut{
      id: flow.id,
      at_step: flow.completed
    }
  end

  def apply(_flow, e = %Events.Created{}) do
    %__MODULE__{
      id: e.id,
      steps: e.steps,
      completed: 0
    }
  end

  def apply(flow, e = %Events.StepCompleted{}) do
    %__MODULE__{ flow | completed: e.completed }
  end

  def apply(flow, %Events.FlowCompleted{}) do
    flow
  end

  def apply(flow, %Events.FlowTimedOut{}) do
    # Wipe our steps, simplest way to ensure we can never
    # step again.
    %__MODULE__{ flow | steps: [] }
  end
end
