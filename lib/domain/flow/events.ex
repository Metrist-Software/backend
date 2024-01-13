defmodule Domain.Flow.Events do
  use TypedStruct

  typedstruct module: Created, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :name, String.t()
    field :timeout_minute, pos_integer()
    field :steps, [String.t()]
  end

  typedstruct module: StepCompleted, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :step, String.t()
    field :completed, pos_integer()
  end

  typedstruct module: FlowCompleted, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
  end

  typedstruct module: FlowTimedOut, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :at_step, pos_integer()
  end
end
