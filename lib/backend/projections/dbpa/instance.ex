defmodule Backend.Projections.Dbpa.Instance do
  use Ecto.Schema
  import Ecto.Query
  alias Backend.Repo

  @primary_key {:name, :string, []}
  schema "instances" do

    timestamps()
  end

  def get_instances(account_id) do
    (from i in __MODULE__)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end
end
