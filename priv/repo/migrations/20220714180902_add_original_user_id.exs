defmodule Backend.Repo.Migrations.AddOriginalUserId do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :original_user_id, :string
    end
  end
end
