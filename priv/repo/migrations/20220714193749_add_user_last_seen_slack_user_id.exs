defmodule Backend.Repo.Migrations.AddUserLastSeenSlackUserId do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :last_seen_slack_user_id, :string
    end
    create index(:users, [:last_seen_slack_user_id])
  end
end
