defmodule Backend.Repo.Migrations.AddUserTimezone do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :timezone, :string
    end
  end
end
