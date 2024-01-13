defmodule Backend.Repo.Migrations.AddInternalFlagToAccounts do
  use Ecto.Migration

  def change do
    alter table("accounts") do
      add :is_internal, :boolean, default: false
    end

  end
end
