defmodule Backend.Repo.Migrations.AddHubspotContacts do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :hubspot_contact_id, :string
    end
  end
end
