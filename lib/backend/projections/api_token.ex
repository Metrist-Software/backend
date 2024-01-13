defmodule Backend.Projections.APIToken do
  use Ecto.Schema

  @primary_key {:api_token, :string, []}
  schema "api_tokens" do
    field :account_id, :string

    timestamps()
  end
end
