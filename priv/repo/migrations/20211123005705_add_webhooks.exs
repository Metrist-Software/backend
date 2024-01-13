defmodule Backend.Repo.Migrations.AddWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :instance_name, :string
      add :data, :text
      add :content_type, :string

      timestamps(type: :naive_datetime_usec)
    end
    create index(:webhooks, [:inserted_at, :monitor_logical_name, :instance_name])
  end
end
