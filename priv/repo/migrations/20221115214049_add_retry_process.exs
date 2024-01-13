defmodule Backend.Repo.Migrations.AddRetryProcess do
  use Ecto.Migration

  def change do
    create table(:notification_retry_process, primary_key: false) do
      add :id, :string, primary_key: true

      timestamps()
    end
  end
end
