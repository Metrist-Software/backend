defmodule Backend.Projections.Dbpa.MonitorTwitterInfo do
  @moduledoc """
  Twitter activity configuration data.

  Note that while this is in the DBPA repository, at the moment we only use data
  in "SHARED", hence the default - and expected - argument for the account ID on the
  public functions.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          monitor_logical_name: String.t(),
          hashtags: [String.t()]
        }

  @primary_key {:monitor_logical_name, :string, []}
  schema "monitor_twitter_info" do
    field :hashtags, {:array, :string}
  end

  import Ecto.Query
  alias Backend.Repo

  @spec names(account_id :: String.t()) :: [String.t()]
  def names(account_id \\ "SHARED") do
    from(mti in __MODULE__,
      select: mti.monitor_logical_name
    )
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  @spec get(String.t(), String.t()) :: t() | nil
  def get(monitor_logical_name, account_id \\ "SHARED") do
    from(mti in __MODULE__,
      where: mti.monitor_logical_name == ^monitor_logical_name
    )
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Backend.Repo.one()
  end
end
