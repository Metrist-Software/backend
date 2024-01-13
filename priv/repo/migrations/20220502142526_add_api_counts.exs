defmodule Backend.Repo.Migrations.AddApiCounts do
  use Ecto.Migration

  def change do
    create table(:aggregate_api_use, primary_key: false) do
      add :id, :string, primary_key: true
      add :time, :naive_datetime_usec
      add :account_id, :string
      add :is_internal, :boolean
    end
    create index(:aggregate_api_use, [:time, :is_internal, :account_id])
  end
end
