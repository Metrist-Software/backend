defmodule Backend.DbpaRepo.Migrations.RemoveMonitorConfigFields do
  use Ecto.Migration

  def change do
    alter table(:monitor_configs) do
      remove :check_logical_name
      remove :function_name
    end
  end
end
