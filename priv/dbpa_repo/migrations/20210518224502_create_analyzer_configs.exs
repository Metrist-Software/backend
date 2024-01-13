defmodule Backend.DbpaRepo.Migrations.CreateAnalyzerConfigs do
  use Ecto.Migration

  def change do
    create table(:analyzer_configs, primary_key: false) do
      add :monitor_logical_name, :string, primary_key: true
      add :default_degraded_threshold, :float
      add :instances, :jsonb
      add :check_configs, :jsonb

      timestamps()
    end
  end
end
