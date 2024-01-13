defmodule Backend.Projections.Dbpa.MonitorCheck do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "monitor_checks" do
    field :logical_name, :string, primary_key: true
    field :monitor_logical_name, :string, primary_key: true
    field :name, :string
    field :is_private, :boolean

    timestamps()
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:logical_name, :monitor_logical_name, :name, :is_private])
    |> validate_required([:logical_name, :monitor_logical_name, :name, :is_private])
  end

  import Ecto.Query
  alias Backend.Repo

  def get_combined_checks_for_monitor(monitor_logical_name, account_id) do
    shared_query =
      __MODULE__
      |> where([c], c.monitor_logical_name == ^monitor_logical_name)
      |> select([c], c)
      |> put_query_prefix(Repo.schema_name(nil))


    __MODULE__
    |> where([c], c.monitor_logical_name == ^monitor_logical_name)
    |> select([c], c)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> union(^shared_query)
    |> Repo.all()
  end

  @spec get_checks_for_monitors(String.t, [String.t]) :: %{ String.t => [String.t] }
  def get_checks_for_monitors(account_id, monitor_logical_names) do
    __MODULE__
    |> where([c], c.monitor_logical_name in ^monitor_logical_names)
    |> select([c], c)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
    |> Enum.group_by(&(&1.monitor_logical_name)) # In memory group by to turn this into a map but this will be a small list even with 100 monitors
  end
end
