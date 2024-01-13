use TypedStruct

typedstruct module: TestStruct do
  plugin(Backend.JsonUtils)

  field :id, String.t()
  field :timestamp, NaiveDateTime.t()
end
