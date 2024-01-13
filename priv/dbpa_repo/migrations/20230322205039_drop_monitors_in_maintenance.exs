defmodule Backend.DbpaRepo.Migrations.DropMonitorsInMaintenance do
  use Ecto.Migration

  def change do
    alter table (:monitors) do
      remove :in_maintenance, :boolean, default: false
    end
  end
end
