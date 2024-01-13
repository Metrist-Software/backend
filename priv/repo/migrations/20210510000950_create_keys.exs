defmodule Backend.Repo.Migrations.CreateKeys do
  use Ecto.Migration

  def change do
    create table(:keys, primary_key: false) do
      add :id, :string, primary_key: true
      add :key_id, :string
      add :scheme, :string
      add :owner_type, :string
      add :owner_id, :string
      add :is_default, :boolean, default: false, null: false
      add :key, :string

      timestamps()
    end
    create unique_index("keys", [:owner_type, :owner_id, :is_default])
  end
end
