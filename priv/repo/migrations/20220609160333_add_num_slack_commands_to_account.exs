defmodule Backend.Repo.Migrations.AddNumSlackCommandsToAccount do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :stat_num_slack_commands, :integer, default: 0
    end
  end
end
