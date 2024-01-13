defmodule Backend.Repo.Migrations.AddCorrelationIdIndexToMonitorEvents do
  use Ecto.Migration

  def change do
    create index(:monitor_events, [:correlation_id, :inserted_at])
  end
end
