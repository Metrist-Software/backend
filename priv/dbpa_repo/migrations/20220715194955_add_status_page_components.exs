defmodule Backend.DbpaRepo.Migrations.AddStatusPageComponents do
  use Ecto.Migration

  def change do
    create table(:status_page_components, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:status_page_id, :string)
      add(:name, :string)
      add(:exists, :boolean)
      add(:recent_change_id, :string)

      timestamps()
    end

    create(index(:status_page_components, [:status_page_id, :recent_change_id]))
  end
end
