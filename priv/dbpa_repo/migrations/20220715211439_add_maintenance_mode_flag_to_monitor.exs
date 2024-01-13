defmodule Backend.Repo.Migrations.AddMaintenanceModeFlagToMonitor do
  use Ecto.Migration

  def change do
    alter table (:monitors) do
      add :in_maintenance, :boolean, default: false
    end
  end
end
