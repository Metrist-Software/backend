defmodule Backend.Crypto.Key do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "keys" do
    field :is_default, :boolean, default: false
    field :key, :string, redact: true
    field :key_id, :string
    field :owner_id, :string
    field :owner_type, :string
    field :scheme, :string

    timestamps()
  end
end
