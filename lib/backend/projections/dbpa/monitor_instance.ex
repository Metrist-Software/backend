defmodule Backend.Projections.Dbpa.MonitorInstance do
  use Ecto.Schema

  @primary_key false
  schema "monitor_instances" do
    field :monitor_logical_name, :string, primary_key: true
    field :instance_name, :string, primary_key: true
    field :last_report, :naive_datetime_usec
    field :check_last_reports, :map

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def list_all_instances() do
    from(m in __MODULE__, select: m.instance_name, order_by: m.instance_name)
    |> put_query_prefix(Repo.schema_name(nil))
    |> distinct(true)
    |> Repo.all()
  end

  def get_monitor_instances(account_id, monitor_logical_name) do
    (from i in __MODULE__,
      where: i.monitor_logical_name == ^monitor_logical_name)
    |> Repo.all(prefix: Repo.schema_name(account_id))
  end

  def get_monitor_instances_for_instance(account_id, instance_name) do
    (from i in __MODULE__,
      where: i.instance_name == ^instance_name)
    |> Repo.all(prefix: Repo.schema_name(account_id))
  end

  @doc """
  If an account has monitor instances, it has (or had) an agent running and
  "private" monitoring data.
  """
  def has_monitor_instances(account_id) do
    Repo.aggregate(__MODULE__, :count, prefix: Repo.schema_name(account_id)) > 0
  end

  @doc """
  Active instances are those that got a report in the last day.
  """
  def get_active_monitor_instance_names(account_id) do
    since = NaiveDateTime.utc_now() |> NaiveDateTime.add(-24, :hour)
    (from i in __MODULE__,
      select: i.instance_name,
      distinct: true,
      where: i.last_report >= ^since)
    |> Repo.all(prefix: Repo.schema_name(account_id))
  end

  def get_instances_for_monitors(account_id, monitor_logical_names) do
    __MODULE__
    |> where([c], c.monitor_logical_name in ^monitor_logical_names)
    |> select([c], c)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
    |> Enum.group_by(&(&1.monitor_logical_name)) # In memory group by to turn this into a map but this will be a small list even with 100 monitors
  end

end
