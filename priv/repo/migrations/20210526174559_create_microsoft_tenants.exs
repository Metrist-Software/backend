defmodule Backend.Repo.Migrations.CreateMicrosoftTenants do
  use Ecto.Migration

  def change do
    create table(:microsoft_tenants, primary_key: false) do
      add :id, :string, primary_key: true
      add :account_id, :string
      add :team_id, :string
      add :team_name, :string
      add :service_url, :string
    end
  end
end
