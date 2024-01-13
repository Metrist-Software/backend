defmodule Backend.DbpaRepo.Migrations.CreateAlertDeliveries do
  use Ecto.Migration

  def change do
    create table(:alert_deliveries, primary_key: false) do
      add :id, :string, primary_key: true
      add :alert_id, :string
      add :delivery_method, :string
      add :delivered_by_region, :string
      add :started_at, :naive_datetime_usec
      add :completed_at, :naive_datetime_usec

      timestamps()
    end

    create index(:alert_deliveries, [:delivery_method, :alert_id])
    create index(:alert_deliveries, [:alert_id])
    create index(:alert_deliveries, [:started_at])
  end
end
