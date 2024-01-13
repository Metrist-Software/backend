defmodule Backend.Repo.Migrations.AddSnapshotCorrelationId do
  use Ecto.Migration

  def change do
    alter table ("monitor_events") do
      add :correlation_id, :string
    end

    alter table ("alerts") do
      add :correlation_id, :string
    end
  end
end
