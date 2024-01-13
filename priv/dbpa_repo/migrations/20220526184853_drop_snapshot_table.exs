defmodule Backend.Repo.Migrations.DropSnapshotTable do
  use Ecto.Migration

  def change do
    drop table(:snapshots)
  end
end
