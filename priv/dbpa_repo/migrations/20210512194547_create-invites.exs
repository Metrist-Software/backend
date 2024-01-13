defmodule :"Elixir.Backend.DbpaRepo.Migrations.Create-invites" do
  use Ecto.Migration

  def change do
    create table(:invites, primary_key: false) do
      add :id, :string, primary_key: true
      add :invitee_id, :string
      add :inviter_id, :string

      timestamps()
    end
  end
end
