defmodule Backend.Repo.Migrations.AddMonitorTwitterInfo do
  use Ecto.Migration

  def change do
    create table(:monitor_twitter_info, primary_key: false) do
      add :monitor_logical_name, :string, primary_key: true
      add :hashtags, {:array, :string}
    end

    create table(:monitor_twitter_counts, primary_key: false) do
      add :monitor_logical_name, :string, primary_key: true
      add :hashtag, :string, primary_key: true
      add :bucket_end_time, :naive_datetime_usec, primary_key: true
      add :bucket_duration, :integer
      add :count, :integer
    end
  end
end
