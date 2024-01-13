defmodule Backend.Repo.Migrations.CreateVisibleMonitors do
  use Ecto.Migration

  def change do
    create table(:visible_monitors, primary_key: false) do
      add :monitor_logical_name, :string, primary_key: true
    end
  end
end
