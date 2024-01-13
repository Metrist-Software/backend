defmodule Backend.Repo.Migrations.AddAppUseAggregate do
  use Ecto.Migration

  def change do
    create table(:aggregate_app_use, primary_key: false) do
      add :id, :string, primary_key: true
      add :time, :naive_datetime_usec
      add :user_id, :string
      add :app_type, :string
      add :is_internal, :boolean
    end
    create index(:aggregate_app_use, [:time, :is_internal, :app_type, :user_id])
  end
end
