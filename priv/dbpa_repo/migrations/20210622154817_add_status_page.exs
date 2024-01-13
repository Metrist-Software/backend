defmodule Backend.Repo.Migrations.AddStatusPage do
  use Ecto.Migration

  @moduledoc """
  Tables for status pages. Note that we add this to DBPA: currently we'll only
  have SHARED, but this is an easy way to later on add private status page observations
  if we want to. Also meshes well with keeping all shared data in that special DBPA.
  """

  def change do

    create table(:status_pages, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
    end

    create unique_index(:status_pages, [:name])

    create table(:status_page_component_changes, primary_key: false) do
      add :id, :string, primary_key: true
      add :status_page_id, references(:status_pages, type: :string)
      add :component_name, :string
      add :status, :string
      add :instance, :string
      add :changed_at, :naive_datetime_usec
    end

    create index(:status_page_component_changes, [:status_page_id, :changed_at])
  end
end
