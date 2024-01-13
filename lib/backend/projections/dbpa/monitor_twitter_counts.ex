defmodule Backend.Projections.Dbpa.MonitorTwitterCounts do
  @moduledoc """
  Persisted Twitter counts.

  This acts mostly as a backing store for the in-memory workers, but it is
  stored in a way that makes it easily accessible for other use cases as well.

  Note that while this is in the DBPA repository, at the moment we only use data
  in "SHARED", hence the default - and expected - argument for the account ID on the
  public functions.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          monitor_logical_name: String.t(),
          hashtag: String.t(),
          bucket_end_time: NaiveDateTime.t(),
          bucket_duration: pos_integer(),
          count: non_neg_integer()
        }

  @primary_key false
  schema "monitor_twitter_counts" do
    field :monitor_logical_name, :string, primary_key: true
    field :hashtag, :string, primary_key: true
    field :bucket_end_time, :naive_datetime_usec, primary_key: true
    field :bucket_duration, :integer
    field :count, :integer
  end

  import Ecto.Query
  alias Backend.Repo

  @doc """
  Get all counts for the monitor/hashtag. The resulting counts are
  ordered chronologically (oldest one first)
  """
  @spec get(String.t(), String.t(), String.t()) :: t()
  def get(monitor_logical_name, hashtag, account_id \\ "SHARED") do
    from(r in __MODULE__,
      where:
        r.monitor_logical_name == ^monitor_logical_name and
          r.hashtag == ^hashtag,
      order_by: r.bucket_end_time
    )
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end
end
