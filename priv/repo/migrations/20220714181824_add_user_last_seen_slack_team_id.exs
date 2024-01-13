defmodule Backend.Repo.Migrations.AddUserLastSeenSlackTeamId do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :last_seen_slack_team_id, :string
    end
  end
end
