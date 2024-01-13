defmodule Backend.Projections.Dbpa.Subscription do
  use Ecto.Schema

  @type t :: %__MODULE__{
    delivery_method: String.t(),
    identity: String.t(),
    regions: [String.t()],
    extra_config: %{String.t() => String.t()},
    display_name: String.t()
  }

  @primary_key {:id, :string, []}
  @foreign_key_type :string
  schema "subscriptions" do
    field :delivery_method, :string
    field :identity, :string
    field :regions, {:array, :string}
    field :extra_config, :map
    field :display_name, :string

    timestamps()

    belongs_to :monitor, Backend.Projections.Dbpa.Monitor, foreign_key: :monitor_id, references: :logical_name
  end

  def safe_display_name(%__MODULE__{delivery_method: dm, display_name: dn}) when dm in ["pagerduty", "datadog"] do
    ellipsify(dn)
  end
  def safe_display_name(%__MODULE__{delivery_method: "email", display_name: dn}) do
    [box, host] = String.split(dn, "@")
    ellipsify(box) <> "@" <> host
  end
  def safe_display_name(%__MODULE__{delivery_method: "webhook", display_name: dn}) do
    uri = URI.parse(dn)

    full_path =
      case uri.query do
        nil -> uri.path
        q -> uri.path <> q
      end
    full_path =
      case full_path do
        nil -> ""
        <<"/", rest::binary>> -> "/" <> ellipsify(rest)
      end

    uri
    |> URI.merge(full_path)
    |> URI.to_string()
  end
  def safe_display_name(subs), do: subs.display_name

  # Public for testing.
  def ellipsify(nil), do: ""
  def ellipsify(s) do
    case String.length(s) do
      0 -> s
      1 -> s
      2 -> s
      _ -> String.first(s) <> "…" <> String.last(s)
    end
  end

  import Ecto.Query
  alias Backend.Repo

  def active_subscription_count() do
    Backend.Projections.list_accounts(type: :external)
    |> Enum.map(fn acct ->
      Backend.Repo.aggregate(__MODULE__, :count, :id, prefix: Backend.Repo.schema_name(acct))
    end)
    |> Enum.sum()
  end

  def active_subscription_count(account_id) do
    :external
    Backend.Repo.aggregate(__MODULE__, :count, :id, prefix: Backend.Repo.schema_name(account_id))
  end

  def get_subscriptions_for_account(account_id, preloads \\ []) do
    :external
    Backend.Repo.all(__MODULE__, prefix: Repo.schema_name(account_id))
    |> Repo.preload(preloads)
  end

  def get_subscriptions_for_monitor(account_id, monitor_logical_name, preloads \\ []) do
    (from s in __MODULE__, where: s.monitor_id == ^monitor_logical_name)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> preload(^preloads)
    |> Repo.all()
  end

  def get_slack_subscriptions_for_account_and_identity(account_id, identity, preloads \\ []) do
    (from s in __MODULE__, where: s.delivery_method == "slack" and s.identity == ^identity)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> preload(^preloads)
    |> Repo.all()
  end

  def get_slack_subscriptions_for_workspace(account_id, workspace_id, preloads \\ []) do
    (from s in __MODULE__, where: s.delivery_method == "slack" and fragment("extra_config->>'WorkspaceId'") == ^workspace_id)
    |> put_query_prefix(Repo.schema_name(account_id))
    |> preload(^preloads)
    |> Repo.all()
  end
end
