defmodule Backend.Repo.Migrations.UpdateMonitorErrorIndex do
  use Ecto.Migration

  def change do
    drop_if_exists index(:monitor_errors, [:time])
    create index(:monitor_errors, [:time, :monitor_logical_name])
  end
end
