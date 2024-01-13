defmodule Backend.DbpaRepo.Migrations.AddAnalyzerConfigNewDefaults do
  use Ecto.Migration

  def change do
    alter table("analyzer_configs") do
      add :default_degraded_down_count, :integer
      add :default_degraded_up_count, :integer
      add :default_degraded_timeout, :integer
      add :default_error_timeout, :integer
      add :default_error_down_count, :integer
      add :default_error_up_count, :integer
    end
  end
end
