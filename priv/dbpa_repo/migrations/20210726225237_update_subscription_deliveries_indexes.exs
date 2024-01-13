defmodule Backend.DbpaRepo.Migrations.UpdateSubscriptionDeliveriesIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists index(:subscription_deliveries, [:monitor_logical_name])
    create index(:subscription_deliveries, [:monitor_logical_name, :inserted_at])
  end
end
