defmodule Backend.Projections.Dbpa.AlertDelivery do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "alert_deliveries" do
    field :alert_id, :string
    field :delivery_method, :string
    field :delivered_by_region, :string
    field :started_at, :naive_datetime_usec
    field :completed_at, :naive_datetime_usec

    timestamps()
  end

  def alert_delivery_count() do
    Backend.Projections.list_accounts(type: :external)
    |> Enum.map(fn acct ->
      Backend.Repo.aggregate(__MODULE__, :count, :id, prefix: Backend.Repo.schema_name(acct))
    end)
    |> Enum.sum()
  end
end
