defmodule Domain.Flow.Commands do
  use TypedStruct

  typedstruct module: Create, enforce: true do
    use Domo
    field :id, String.t()
    field :name, String.t()
    field :timeout_minute, pos_integer()
    field :steps, [String.t()]
  end

  typedstruct module: Step, enforce: true do
    use Domo
    field :id, String.t()
    field :step, String.t()
  end

  typedstruct module: Timeout, enforce: true do
    use Domo
    field :id, String.t()
  end
end
