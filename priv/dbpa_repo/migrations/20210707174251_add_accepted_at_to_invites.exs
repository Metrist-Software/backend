defmodule Backend.DbpaRepo.Migrations.AddAcceptedAtToInvites do
  use Ecto.Migration

  def change do
    alter table (:invites) do
      add :accepted_at, :naive_datetime_usec
    end
  end
end
