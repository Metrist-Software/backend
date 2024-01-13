defmodule Backend.Repo.Migrations.AddLastWebappActivityToAccount do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :stat_last_webapp_activity, :naive_datetime
    end
  end
end
