defmodule Backend.Repo.Migrations.AddAccountAnalyticsColumns do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :stat_num_subscriptions, :integer, default: 0
      add :stat_num_monitors, :integer, default: 0
      add :stat_num_users, :integer, default: 0
      add :stat_last_user_login, :naive_datetime
      add :stat_num_msteams, :integer, default: 0
      add :stat_num_slack, :integer, default: 0
      add :stat_weekly_users, :integer, default: 0
      add :stat_monthly_users, :integer, default: 0
    end
  end
end
