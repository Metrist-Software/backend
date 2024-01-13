defmodule Backend.Repo.Migrations.AddAccountFreeTrialEndTime do
  use Ecto.Migration

  def change do
    alter table("accounts") do
      add :free_trial_end_time, :naive_datetime
    end
  end
end
