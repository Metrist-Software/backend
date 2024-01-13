defmodule Backend.DbpaRepo.Migrations.CreateMonitorConfigs do
  use Ecto.Migration

  def change do
    create table(:monitor_configs, primary_key: false) do
      add :id, :string, primary_key: true
      add :monitor_logical_name, :string
      add :check_logical_name, :string
      add :function_name, :string
      add :interval_secs, :integer
      add :extra_config, :jsonb
      add :run_groups, :jsonb

      timestamps()
    end
    create unique_index(:monitor_configs, [:monitor_logical_name, :check_logical_name])
  end
end
