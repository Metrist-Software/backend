defmodule Backend.DbpaRepo.Migrations.AddMonitorNameToAlerts do
  use Ecto.Migration

  def change do
    alter table ("alerts") do
      add :monitor_name, :string
    end
  end
end
