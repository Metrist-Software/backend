defmodule Backend.DbpaRepo.Migrations.CreateSubscriptionDeliveries do
  use Ecto.Migration

  def change do
    create table(:subscription_deliveries, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :alert_id, :string
      add :subscription_id, :string
      add :result, :text
      add :status_code, :integer

      timestamps()
    end

    create index(:subscription_deliveries, [:alert_id])
    create index(:subscription_deliveries, [:monitor_logical_name])
    create index(:subscription_deliveries, [:subscription_id])
  end
end
