defmodule Backend.DbpaRepo.Migrations.RemoveIssuesSourceField do
  use Ecto.Migration

  def change do
    alter table (:issues) do
      remove :source
    end
  end
end
