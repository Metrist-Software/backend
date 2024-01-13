defmodule Backend.Repo.Migrations.AddMicrosoftTenantName do
  use Ecto.Migration

  def change do
    alter table ("microsoft_tenants") do
      add :name, :string
    end
  end
end
