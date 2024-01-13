defmodule Backend.Repo.Migrations.AddUserIsAdmin do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :is_admin, :boolean, default: false
    end
  end
end
