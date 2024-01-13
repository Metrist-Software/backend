defmodule Backend.DbpaRepo.Migrations.AddKeysetPaginationIndexForStatusPageChanges do
  use Ecto.Migration

  def change do
    create index(:status_page_component_changes, [:changed_at, :id])
  end
end
