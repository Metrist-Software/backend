defmodule Backend.DbpaRepo.Migrations.AddInsertedAtToSubscriptions do
  use Ecto.Migration
  alias Ecto.Migration.Runner

  def change do
    alter table (:subscriptions) do
      timestamps([default: NaiveDateTime.utc_now() |> to_string])
    end
  end
end
