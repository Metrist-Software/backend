defmodule Backend.Projections.Dbpa.StatusPage.StatusPageComponent do
  @moduledoc """
  A projection(s) table to hold the aggregated state data for the component of an
  associated status page
  """

  use Ecto.Schema
  alias Backend.Repo
  import Ecto.Query

  @type t :: %__MODULE__{
          id: binary(),
          status_page_id: binary(),
          name: binary(),
          recent_change_id: String.t(),
        }
  @primary_key {:id, :string, []}
  schema "status_page_components" do
    field :status_page_id, :string
    field :name, :string
    field :recent_change_id, :string

    timestamps()
  end

  def component_by_page_id_and_name(status_page_id, name),
    do: component_by_page_id_and_name(Domain.Helpers.shared_account_id(), status_page_id, name)

  def component_by_page_id_and_name(account_id, status_page_id, name) do
    from(c in __MODULE__, where: c.status_page_id == ^status_page_id and c.name == ^name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.one()
  end

  def components_by_id(account_id, ids) when is_list(ids) do
    from(c in __MODULE__, where: c.id in ^ids)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def component_by_id(account_id, id) do
    from(c in __MODULE__, where: c.id == ^id)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.one()
  end

  def components(account_id, status_page_id) do
    from(c in __MODULE__, where: c.status_page_id == ^status_page_id)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def all_components_for_account(account_id) do
    from(c in __MODULE__)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

end
