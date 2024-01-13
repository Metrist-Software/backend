defmodule Backend.Repo.Migrations.CreateSlackSlashCommands do
  use Ecto.Migration

  def change do
    create table(:slack_slash_commands, primary_key: false) do
      add :id, :string, primary_key: true
      add :data, :jsonb

      timestamps()
    end
  end
end
