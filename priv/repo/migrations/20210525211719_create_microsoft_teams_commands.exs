defmodule Backend.Repo.Migrations.CreateMicrosoftTeamsCommands do
  use Ecto.Migration

  def change do
    create table(:microsoft_teams_commands, primary_key: false) do
      add :id, :string, primary_key: true
      add :data, :jsonb

      timestamps()
    end
  end
end
