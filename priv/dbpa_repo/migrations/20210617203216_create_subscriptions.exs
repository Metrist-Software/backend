defmodule Backend.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_id, :string
      add :delivery_method, :string
      add :identity, :string
      add :regions, {:array, :string}
      add :extra_config, :jsonb
    end

    create index(:subscriptions, [:delivery_method, :monitor_id])
    create index(:subscriptions, [:delivery_method, :identity])
  end
end
