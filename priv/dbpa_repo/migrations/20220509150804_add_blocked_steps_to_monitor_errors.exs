defmodule Backend.Repo.Migrations.AddBlockedStepsToMonitorErrors do
  use Ecto.Migration

  def change do
    alter table(:monitor_errors) do
      add :blocked_steps, {:array, :string}
    end
  end
end
