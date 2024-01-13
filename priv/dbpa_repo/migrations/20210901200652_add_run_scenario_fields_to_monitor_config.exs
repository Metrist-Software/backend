defmodule Backend.Repo.Migrations.AddRunScenarioFieldsToMonitorConfig do
  use Ecto.Migration

  def change do
    alter table("monitor_configs") do
      add :run_spec, :jsonb
      add :steps, :jsonb
    end
  end
end
