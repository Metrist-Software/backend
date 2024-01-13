defmodule Backend.Repo.Migrations.AddIssueEvents do
  use Ecto.Migration

  def change do
    create table(:issue_events, primary_key: false) do
      add :id,                 :string, primary_key: true
      add :issue_id,           references(:issues, type: :string)
      add :source,             :string
      add :source_id,          :string
      add :check_logical_name, :string
      add :component_id,       :string
      add :state,              :string
      add :region,             :string
      add :start_time,         :naive_datetime_usec
      timestamps()
    end
  end
end
