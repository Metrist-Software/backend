defmodule Backend.DbpaRepo.Migrations.AddKeysetPaginationIndexForMonitorErrors do
  use Ecto.Migration

  def change do
    create index(:monitor_errors, [:time, :id])
  end
end
