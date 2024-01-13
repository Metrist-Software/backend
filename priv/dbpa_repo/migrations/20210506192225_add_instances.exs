defmodule Backend.DbpaRepo.Migrations.AddInstances do
  use Ecto.Migration

  def change do
    create table(:instances, primary_key: false) do
      add :name, :string, primary_key: true

      timestamps()
    end
  end
end
