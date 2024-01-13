defmodule Backend.Repo.Migrations.AddLastLogin do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_login, :naive_datetime_usec
    end

    create index(:users, [:last_login])
  end
end
