defmodule Backend.Repo.Migrations.AddWebLoginAggregate do
  use Ecto.Migration

  def change do
    create table(:aggregate_web_login, primary_key: false) do
      add :id, :string, primary_key: true
      add :time, :naive_datetime_usec
      add :user_id, :string
      add :is_internal, :boolean
    end
    create index(:aggregate_web_login, [:time, :is_internal, :user_id])
  end
end
