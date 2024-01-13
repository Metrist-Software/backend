defmodule Backend.Repo.Migrations.AddDatadogAccessGrants do
  use Ecto.Migration

  def change do
    create table("datadog_access_grants", primary_key: false) do
      add :id, :string, primary_key: true
      add :verifier, :string
      add :access_token, :string
      add :refresh_token, :string
      add :user_id,  references(:users, type: :string)
      add :scope, {:array, :string}
      add :expires_in, :integer
      add :expires_at, :utc_datetime

      timestamps()
    end
    create index("datadog_access_grants", [:user_id], unique: true)
  end
end
