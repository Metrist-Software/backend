defmodule Backend.DbpaRepo.Migrations.UpdateSubscriptionDeliveriesToDenormalizeData do
  use Ecto.Migration

  def change do
    alter table(:subscription_deliveries) do
      add :delivery_method, :string
      add :display_name, :string
    end
  end
end
