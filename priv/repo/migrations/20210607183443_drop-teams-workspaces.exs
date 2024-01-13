defmodule :"Elixir.Backend.Repo.Migrations.Drop-teams-workspaces" do
  use Ecto.Migration

  def change do
    drop table(:teams_workspaces)
  end
end
