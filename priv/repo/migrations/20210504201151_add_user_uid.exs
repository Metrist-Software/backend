defmodule Backend.Repo.Migrations.AddUserUid do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :uid, :string
    end
  end
end
