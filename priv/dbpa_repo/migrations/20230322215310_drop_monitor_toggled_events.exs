defmodule Backend.DbpaRepo.Migrations.DropMonitorToggledEvents do
  use Ecto.Migration

  def change do
    drop table(:monitor_toggled_events)
  end
end
