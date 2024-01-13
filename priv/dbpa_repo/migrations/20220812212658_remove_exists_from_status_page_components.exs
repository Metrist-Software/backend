defmodule Backend.DbpaRepo.Migrations.RemoveExistsFromStatusPageComponents do
  use Ecto.Migration

  def change do
    alter table(:status_page_components) do
      remove :exists
    end
  end
end
