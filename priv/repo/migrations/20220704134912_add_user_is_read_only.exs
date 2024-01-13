defmodule Backend.Repo.Migrations.AddUserIsReadOnly do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :is_read_only, :boolean, default: false
    end
  end
end
