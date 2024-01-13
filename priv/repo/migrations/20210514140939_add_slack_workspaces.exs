defmodule Backend.Repo.Migrations.AddSlackWorkspaces do
  use Ecto.Migration

  def change do
    create table(:slack_workspaces, primary_key: false) do
      add :id, :string, primary_key: true
      add :account_id, :string
      add :team_name, :string
      add :scope, {:array, :string}
      add :bot_user_id, :string
      add :access_token, :string
    end
  end
end
