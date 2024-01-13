defmodule Backend.DbpaRepo.Migrations.AddStatusPageSubscriptions do
  use Ecto.Migration

  def change do
    create table("status_page_subscriptions", primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:status_page_id, :string)
      add(:component_id, :string)

      timestamps()
    end

    create(index("status_page_subscriptions", [:status_page_id, :component_id], unique: true))
  end
end
