defmodule Backend.DbpaRepo.Migrations.AddStateToStatusPageChanges do
  use Ecto.Migration

  def change do
    alter table (:status_page_component_changes) do
      add :state, :string
    end
    create index(:status_page_component_changes, [:state])
  end
end
