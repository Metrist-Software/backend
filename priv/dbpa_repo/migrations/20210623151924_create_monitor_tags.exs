defmodule Backend.Repo.Migrations.CreateMonitorTags do
  use Ecto.Migration

  def change do
    create table(:monitor_tags, primary_key: false) do
      add :monitor_logical_name, :string, primary_key: true
      add :tags, {:array, :string}
    end

    create index(:monitor_tags, [:tags], using: "GIN")
  end
end
