defmodule Backend.Repo.Migrations.AddNumSlackAlertsToAccountAnalyticsColumns do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :stat_num_slack_alerts, :integer, default: 0
    end
  end
end
