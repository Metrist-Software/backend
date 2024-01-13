defmodule Backend.Projections.Dbpa.Alert do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "alerts" do
    field :monitor_logical_name, :string
    field :state, Ecto.Enum, values: Backend.Projections.Dbpa.Snapshot.states()
    field :is_instance_specific, :boolean
    field :subscription_id, :string
    field :formatted_messages, :map
    field :affected_checks, {:array, :map}
    field :affected_regions, {:array, :string}
    field :generated_at, :naive_datetime_usec
    field :correlation_id, :string
    field :monitor_name, :string

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def alert_count() do
    Backend.Projections.list_accounts(type: :external)
    |> Enum.map(fn acct ->
      Backend.Repo.aggregate(__MODULE__, :count, :id, prefix: Backend.Repo.schema_name(acct))
    end)
    |> Enum.sum()
  end

  def get_alert_by_id(account_id, alert_id) do
    (from e in __MODULE__,
      where: e.id == ^alert_id)
      |> put_query_prefix(Repo.schema_name(account_id))
      |> Repo.one()
  end
end
