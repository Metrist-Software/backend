defmodule Backend.DbpaRepo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :state, :string
      add :is_instance_specific, :boolean
      add :subscription_id, :string
      add :formatted_messages, :jsonb
      add :affected_regions, {:array, :string}
      add :affected_checks, {:array, :jsonb}
      add :generated_at, :naive_datetime_usec

      timestamps()
    end

    create index(:alerts, [:monitor_logical_name, :state, :generated_at])
    create index(:alerts, [:state, :generated_at])
    create index(:alerts, [:generated_at])
  end
end
