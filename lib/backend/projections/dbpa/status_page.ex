defmodule Backend.Projections.Dbpa.StatusPage do

  defmodule ComponentChange do
    use Ecto.Schema

    @type t :: %__MODULE__{
      id: String.t(),
      status_page_id: String.t(),
      component_name: String.t(),
      status: String.t(),
      state: atom(),
      instance: String.t(),
      changed_at: NaiveDateTime.t()
    }

    @primary_key {:id, :string, []}
    schema "status_page_component_changes" do
      field :status_page_id, :string
      field :component_name, :string
      field :status, :string
      field :state, Ecto.Enum, values: [:up, :degraded, :down, :unknown]
      field :instance, :string
      field :changed_at, :naive_datetime_usec
    end

    def from_event(%Domain.StatusPage.Events.ComponentStatusChanged{} = e) do
      change_state = case Map.get(e, :state) do
        nil -> Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(e.status)
        state -> String.to_atom(state)
      end

      %__MODULE__{
        id: e.change_id,
        status_page_id: e.id,
        component_name: e.component,
        status: e.status,
        state: change_state,
        instance: e.instance,
        changed_at: e.changed_at
      }
    end
  end

  use Ecto.Schema

  @type t :: %__MODULE__{
    name: binary(),
  }

  @primary_key {:id, :string, []}
  schema "status_pages" do
    field :name, :string
    has_many :status_page_component_changes, __MODULE__.ComponentChange,
      foreign_key: :status_page_id
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Dbpa.Snapshot

  # We never return more than this amount of records. Status pages can potentially flap
  # and that is out of our control, we also don't summarize, so we need to set limits in
  # order not to blow through memory.
  @limit 500

  def status_page_by_name(account_id, name) do
    (from sp in __MODULE__, where: sp.name == ^name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.one()
  end

  def status_pages_by_id(account_id, ids) do
    (from sp in __MODULE__, where: sp.id in ^ids)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def status_page_by_id(account_id, id) do
    (from sp in __MODULE__, where: sp.id == ^id)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.one()
  end

  def status_page_changes(account_id, monitor, timespan) do
    cutoff = Backend.Telemetry.cutoff_for_timespan(timespan)
    query = from c in ComponentChange,
      join: p in __MODULE__,
      on: p.id == c.status_page_id,
      where: p.name == ^monitor and c.changed_at > ^cutoff,
      select: %{component_name: c.component_name, status: c.status, changed_at: c.changed_at},
      order_by: [desc: c.changed_at],
      limit: @limit

    query
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
    |> Enum.reverse()
  end

  @spec component_changes_from_change_ids(String.t(), list(String.t())) :: [ComponentChange.t()]
  def component_changes_from_change_ids(account_id, change_ids) do
    from(c in ComponentChange, where: c.id in ^change_ids)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def component_changes(account_id, monitor, start_time,  end_time) do
    query = from c in ComponentChange,
      join: p in __MODULE__,
      on: p.id == c.status_page_id,
      where: p.name == ^monitor and c.changed_at >= ^start_time and c.changed_at <= ^end_time,
      order_by: [asc: :changed_at],
      # Highly unlikely, but better safe than crash while we have a limit any.
      limit: @limit

    query
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  def status_pages_changes_for_active_incident(account_id, monitor, filter_components) do
    # Gets the most recent "up" changes for each component in a given status page
    latest_up = (from c in ComponentChange,
      distinct: c.component_name,
      select: %{component_name: c.component_name, changed_at: c.changed_at},
      join: p in __MODULE__, on: p.id == c.status_page_id,
      where: p.name == ^monitor and c.state == :up,
      order_by: [asc: c.component_name, desc: c.changed_at])
    |> filter_on_components(filter_components)
    |> put_query_prefix(Repo.schema_name(account_id))

    # Gets all of changes that occurred after the most recent up per component
    # If this is non-empty, then there's an incident on the status page
    query = from c in ComponentChange,
      select: c,
      left_join: latest in subquery(latest_up), on: c.component_name == latest.component_name,
      join: p in __MODULE__, on: p.id == c.status_page_id,
      where: p.name == ^monitor and c.changed_at > coalesce(latest.changed_at, ^~N[1970-01-01 00:00:00Z]), # Coalesce on left join to handle no up statuses
      order_by: [asc: c.component_name, desc: c.changed_at]

    query
    |> filter_on_components(filter_components)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.all()
  end

  defp filter_on_components(query, components) do
    where(query, [c], c.component_name in ^components)
  end

  def raw_status_page_changes(account_id, monitor_ids, from, to, opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)
    cursor_after = Keyword.get(opts, :cursor_after)
    cursor_before = Keyword.get(opts, :cursor_before)

    query =
      from c in ComponentChange,
      join: p in __MODULE__, on: p.id == c.status_page_id,
      where: c.changed_at >= ^from,
      select: %{id: c.id, changed_at: c.changed_at, component_name: c.component_name, status: c.status, status_page_name: p.name},
      order_by: [asc: c.changed_at, asc: c.id]

    query =
      if not is_nil(monitor_ids) do
        (from [c, p] in query, where: p.name in ^monitor_ids)
      else
        query
      end

    query = if not is_nil(to), do: (from [c, p] in query, where: c.changed_at <= ^to), else: query

    query
    |> put_query_prefix(Repo.schema_name(account_id))
    |> Repo.paginate(
      before: cursor_before,
      after: cursor_after,
      cursor_fields: [:changed_at, :id],
      limit: limit
    )
  end

  def status_pages do
    Repo.all(__MODULE__, prefix: "dbpa_SHARED")
  end

  # AWS/Azure statuses
  def status_page_status_to_snapshot_state("Good"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("Information"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("Degraded"), do: Snapshot.state_degraded()
  def status_page_status_to_snapshot_state("Warning"), do: Snapshot.state_degraded()
  def status_page_status_to_snapshot_state("Disruption"), do: Snapshot.state_down()
  def status_page_status_to_snapshot_state("Critical"), do: Snapshot.state_down()

  # Azure Dev Ops statuses
  def status_page_status_to_snapshot_state("NotApplicable"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("Avisory"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("Advisory"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("Healthy"), do: Snapshot.state_up()
  # already defined for AWS above - keeping here for completeness
  # def status_page_status_to_snapshot_state("Degraded"), do: Snapshot.state_degraded()
  def status_page_status_to_snapshot_state("Unhealthy"), do: Snapshot.state_down()

  # GCP statuses
  def status_page_status_to_snapshot_state("available"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("information"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("disruption"), do: Snapshot.state_degraded()
  def status_page_status_to_snapshot_state("outage"), do: Snapshot.state_down()

  # Statuspage.io statuses
  def status_page_status_to_snapshot_state("degraded_performance"), do: Snapshot.state_degraded()
  def status_page_status_to_snapshot_state("major_outage"), do: Snapshot.state_down()
  def status_page_status_to_snapshot_state("operational"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("partial_outage"), do: Snapshot.state_down()
  def status_page_status_to_snapshot_state("under_maintenance"), do: Snapshot.state_degraded()

  # 1:1 mapping for our own states
  def status_page_status_to_snapshot_state("up"), do: Snapshot.state_up()
  def status_page_status_to_snapshot_state("down"), do: Snapshot.state_down()
  def status_page_status_to_snapshot_state("degraded"), do: Snapshot.state_degraded()

  def status_page_status_to_snapshot_state(_), do: :unknown

  def limit, do: @limit
end
