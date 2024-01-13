defmodule Backend.Repo.Migrations.RenameIsAdminToIsMetristAdmin do
  use Ecto.Migration

  def change do
    rename table("users"), :is_admin, to: :is_metrist_admin
  end
end
