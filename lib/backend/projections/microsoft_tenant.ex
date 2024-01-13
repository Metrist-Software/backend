defmodule Backend.Projections.MicrosoftTenant do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "microsoft_tenants" do
    field :account_id, :string
    field :name, :string
    field :team_id, :string
    field :team_name, :string
    field :service_url, :string
  end

  import Ecto.Query
  alias Backend.Repo

  def get_microsoft_tenants(account_id) do
    from(mt in __MODULE__, where: mt.account_id == ^account_id)
    |> Repo.all()
  end

  def has_microsoft_tenants?(account_id) do
    from(mt in __MODULE__, where: mt.account_id == ^account_id)
    |> Repo.exists?()
  end
end
