defmodule Backend.Repo.Migrations.AddNewSignups do
  use Ecto.Migration

  def change do
    create table(:aggregate_new_signups, primary_key: false) do
      add :id, :string, primary_key: true
      add :time, :naive_datetime_usec
    end
    create index(:aggregate_new_signups, [:time])
  end
end
