defmodule Domain.Notice.Events do
  use TypedStruct

  typedstruct module: Created do
    plugin Backend.JsonUtils
    field :id, String.t(), enforce: true
    field :monitor_id, String.t()
    field :summary, String.t(), enforce: true
    field :description, String.t()
    field :end_date, DateTime.t()
  end

  typedstruct module: ContentUpdated do
    plugin Backend.JsonUtils
    field :id, String.t(), enforce: true
    field :summary, String.t(), enforce: true
    field :description, String.t()
  end

  typedstruct module: EndDateUpdated, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :end_date, DateTime.t()
  end

  typedstruct module: MarkedRead, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :user_id, String.t()
  end
end
