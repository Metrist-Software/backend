defmodule Backend.Datadog.AccessGrants do
  use Ecto.Schema
  import Ecto.Query

  @primary_key {:id, :string, []}
  schema "datadog_access_grants" do
    field :verifier, :string
    field :user_id, :string
    field :access_token, :string
    field :refresh_token, :string
    field :scope, {:array, :string}
    field :expires_in, :integer
    field :expires_at, :utc_datetime

    timestamps()
  end

  def get_by_user_id(user_id) do
    __MODULE__
    |> where(user_id: ^user_id)
    |> Backend.Repo.one()
  end
end
