defmodule Domain.Notice.Commands do
  use TypedStruct

  typedstruct module: Create do
    use Domo
    field :id, String.t(), enforce: true
    field :monitor_id, String.t()
    field :summary, String.t(), enforce: true
    field :description, String.t()
    field :end_date, NaiveDateTime.t()
  end

  typedstruct module: Update do
    use Domo
    field :id, String.t(), enforce: true
    field :summary, String.t(), enforce: true
    field :description, String.t()
    field :end_date, NaiveDateTime.t()
  end

  typedstruct module: Clear do
    use Domo
    field :id, String.t(), enforce: true
  end

  typedstruct module: MarkRead, enforce: true do
    use Domo
    field :id, String.t()
    field :user_id, String.t()
  end
end
