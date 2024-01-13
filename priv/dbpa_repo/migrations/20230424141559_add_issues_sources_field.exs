defmodule Backend.DbpaRepo.Migrations.AddIssuesSourcesField do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      add :sources, {:array, :string}, default: []
    end
  end
end
