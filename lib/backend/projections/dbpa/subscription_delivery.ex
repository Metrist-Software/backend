defmodule Backend.Projections.Dbpa.SubscriptionDelivery do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  @foreign_key_type :string
  schema "subscription_deliveries" do
    field :result, :string
    field :status_code, :integer
    field :delivery_method, :string
    field :display_name, :string

    belongs_to :alert, Backend.Projections.Dbpa.Alert
    belongs_to :subscription, Backend.Projections.Dbpa.Subscription
    belongs_to :monitor, Backend.Projections.Dbpa.Monitor, foreign_key: :monitor_logical_name, references: :logical_name

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def get_subscription_delivery(account_id, id, preloads \\ []) do
    Repo.get!(__MODULE__, id, prefix: Repo.schema_name(account_id))
    |> Repo.preload(preloads)
  end

  def subscription_deliveries_since(account_id, monitor_logical_name, hours, preloads \\ []) do
    from_datetime = NaiveDateTime.utc_now()
    |> NaiveDateTime.add(60*60*hours*-1, :second)

    query = from sd in __MODULE__,
            where: sd.inserted_at >= ^from_datetime

    query
    |> with_monitor(monitor_logical_name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> preload(^preloads)
    |> order_by([desc: :inserted_at])
    |> Repo.all()
  end

  defp with_monitor(query, nil), do: query
  defp with_monitor(query, []), do: query
  defp with_monitor(query, logical_name) when is_list(logical_name) do
    query
    |> where([e], e.monitor_logical_name in ^logical_name)
  end
  defp with_monitor(query, logical_name) do
    query
    |> where([e], e.monitor_logical_name == ^logical_name)
  end

  def subscription_delivery_count() do
    Backend.Projections.list_accounts()
    |> Enum.map(fn acct ->
      Backend.Repo.aggregate(__MODULE__, :count, :id, prefix: Backend.Repo.schema_name(acct))
    end)
    |> Enum.sum()
  end
end
