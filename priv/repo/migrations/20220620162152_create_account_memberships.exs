defmodule Backend.Repo.Migrations.CreateAccountMemberships do
  use Ecto.Migration

  def change do
    create table(:memberships, primary_key: false) do
      add :id, :string, primary_key: true
      add :account_id, :string
      add :tier, :string
      add :billing_period, :string
      add :start_date, :naive_datetime
      add :end_date, :naive_datetime

      timestamps()
    end

    create index(:memberships, [:account_id, :end_date])
  end
end
