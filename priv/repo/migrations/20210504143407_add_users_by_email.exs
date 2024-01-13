defmodule Backend.Repo.Migrations.AddUsersByEmail do
  use Ecto.Migration

  def change do
    create index(:users, [:email])
  end
end
