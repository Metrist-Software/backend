defmodule Backend.Repo.Migrations.AddIsValidColumn do
  use Ecto.Migration

  def change do
    alter table ("monitor_events") do
      add :is_valid, :boolean, default: true
    end
    alter table ("monitor_errors") do
      add :is_valid, :boolean, default: true
    end
  end
end
