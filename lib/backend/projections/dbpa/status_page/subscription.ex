defmodule Backend.Projections.Dbpa.StatusPage.StatusPageSubscription do
  @moduledoc """
    Stores the status page subscription of an account. The `status_page_id` references a
    `status_page` row in the SHARED account
  """
  use Ecto.Schema
  alias Backend.Repo
  import Ecto.Query

  @type t :: %__MODULE__{
          id: binary(),
          status_page_id: binary(),
          component_id: binary()
        }

  @primary_key {:id, :string, []}
  schema "status_page_subscriptions" do
    field :status_page_id, :string
    field :component_id, :string

    timestamps()
  end

  def from_event(%Domain.StatusPage.Events.SubscriptionAdded{} = e) do
    %Backend.Projections.Dbpa.StatusPage.StatusPageSubscription{
      id: e.subscription_id,
      status_page_id: e.id,
      component_id: e.component_id
    }
  end

  def subscriptions(account_id) do
    from(sp in __MODULE__)
      |> put_query_prefix(Repo.schema_name(account_id))
      |> Repo.all()
  end

  def subscriptions(account_id, status_page_id) do
    from(sp in __MODULE__, where: sp.status_page_id == ^status_page_id)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def subscriptions_by_filter(account_id, where_filter) do
    from(sp in __MODULE__, where: ^where_filter)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def account_subscribed_to_status_page_component?(account_id, status_page_id, component_id) do
    from(sp in __MODULE__, where: [status_page_id: ^status_page_id, component_id: ^component_id])
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.exists?()
  end
end
