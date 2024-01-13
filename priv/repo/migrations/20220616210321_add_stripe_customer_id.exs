defmodule Backend.Repo.Migrations.AddStripeCustomerId do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :stripe_customer_id, :string
    end
  end
end
