defmodule Backend.DbpaRepo.Migrations.AddIndexToIssueAndIssueEvents do
  use Ecto.Migration

  def change do
    create index(:issues, [:service])
    create index(:issues, [:start_time])
    create index(:issues, [:end_time])
    create index(:issues, [:start_time, :id])

    create index(:issue_events, [:start_time])
    create index(:issue_events, [:issue_id])
    create index(:issue_events, [:start_time, :id])
  end
end
