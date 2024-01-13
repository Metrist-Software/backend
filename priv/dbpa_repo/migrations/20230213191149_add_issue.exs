defmodule Backend.Repo.Migrations.AddIssue do
  use Ecto.Migration

  def change do
    create table(:issues, primary_key: false) do
      add :id,          :string, primary_key: true
      add :source,      :string
      add :worst_state, :string
      add :service,     :string
      add :start_time,  :naive_datetime_usec
      add :end_time,    :naive_datetime_usec
      timestamps()
    end
  end
end
