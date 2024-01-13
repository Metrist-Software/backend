defmodule Backend.Repo.Migrations.CreateNotices do
  use Ecto.Migration

  def change do
    create table(:notices, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_id, :string
      add :summary, :string
      add :description, :text
      add :end_date, :naive_datetime

      timestamps()
    end

    create index(:notices, [:monitor_id])
    create index(:notices, [:end_date])
  end
end
