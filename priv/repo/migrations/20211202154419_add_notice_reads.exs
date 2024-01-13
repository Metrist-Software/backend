defmodule Backend.Repo.Migrations.AddNoticeReads do
  use Ecto.Migration

  def change do
    create table("notice_reads", primary_key: false) do
      add :notice_id, references(:notices, type: :string)
      add :user_id, references(:users, type: :string)
      timestamps()
    end
  end
end
