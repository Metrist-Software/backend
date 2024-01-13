defmodule Backend.Repo.Migrations.CreateTeamsWorkspaces do
  use Ecto.Migration

  def change do
    create table(:teams_workspaces, primary_key: false) do
      add :tenant_uuid, :string, primary_key: true
      add :account_id, :string
    end
  end
end
