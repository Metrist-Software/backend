defmodule Backend.Projections.Account do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "accounts" do
    field :name, :string
    field :is_internal, :boolean
    field :stripe_customer_id, :string
    field :original_user_id, :string

    has_many :memberships, Backend.Projections.Membership,
      foreign_key: :account_id

    has_many :microsoft_tenants, Backend.Projections.MicrosoftTenant,
      foreign_key: :account_id

    has_many :slack_workspaces, Backend.Projections.SlackWorkspace,
      foreign_key: :account_id

    has_one :original_user, Backend.Projections.User

    timestamps()

    # There's no real good reason to have a second table with a 1:1 relationship just for statistics. Instead,
    # we just add a bunch of fields with the `stat_` prefix. We can always change our mind later and split it
    # off or move it someplace else.

    field :stat_num_subscriptions, :integer
    field :stat_num_monitors, :integer
    field :stat_num_users, :integer
    field :stat_last_user_login, :naive_datetime
    field :stat_last_webapp_activity, :naive_datetime
    field :stat_num_msteams, :integer
    field :stat_num_slack, :integer
    field :stat_num_slack_alerts, :integer
    field :stat_num_slack_commands, :integer
    field :stat_weekly_users, :integer
    field :stat_monthly_users, :integer

    field :free_trial_end_time, :naive_datetime
  end

  import Ecto.Query
  alias Backend.Repo

  def list_accounts(opts \\ []) do
    type = Keyword.get(opts, :type, nil)
    preloads = Keyword.get(opts, :preloads, [])
    sort = Keyword.get(opts, :sort, nil)

    query = from a in __MODULE__

    query
    |> where_is_internal(type)
    |> sort_by(sort)
    |> preload(^preloads)
    |> Repo.all()
  end

  def list_account_ids() do
    from(a in __MODULE__, select: a.id) 
    |> Repo.all()
  end

  defp where_is_internal(query, :internal), do: where(query, [a], a.is_internal == true)
  defp where_is_internal(query, :external), do: where(query, [a], a.is_internal == false)
  defp where_is_internal(query, _), do: query

  defp sort_by(query, %{col: sort_col, dir: sort_dir}) do
    sort_col = String.to_atom(sort_col)
    sort_dir = String.to_atom(sort_dir)
    order = [{sort_dir, sort_col}]

    order_by(query, ^order)
  end
  defp sort_by(query, _), do: query

  def get_account(id, preloads \\ []), do: Repo.get(__MODULE__, id) |> Repo.preload(preloads)
  def get_account!(id), do: Repo.get!(__MODULE__, id)

  def get_accounts_for_monitor(monitor_logical_name, opts \\ []) do
    {extra_opts, _} = Keyword.split(opts, [:list_accounts_opts])
    list_account_opts = Keyword.get(extra_opts, :list_accounts_opts, [])

    Keyword.merge([type: :external], list_account_opts)
    |> list_accounts()
    |> Enum.filter(fn acct ->
      from(s in Backend.Projections.Dbpa.Monitor, where: s.logical_name == ^monitor_logical_name)
      |> put_query_prefix(Repo.schema_name(acct.id))
      |> Repo.exists?()
    end)
  end

  def get_accounts_with_subscription_to_monitor(monitor_logical_name) do
    list_accounts(type: :external)
    |> Enum.filter(fn acct ->
      from(s in Backend.Projections.Dbpa.Subscription, where: s.monitor_id == ^monitor_logical_name)
      |> put_query_prefix(Repo.schema_name(acct.id))
      |> Repo.exists?()
    end)
  end

  def register_account_activity(nil), do: :ok
  def register_account_activity(account_id) do
      now = NaiveDateTime.utc_now()
      query =
        from a in __MODULE__,
          where: a.id == ^account_id,
          update: [
            set: [
              stat_last_webapp_activity: ^now
            ]
          ]
      Repo.update_all(query, [])
  end

  def get_account_name(account, default \\ nil)
  def get_account_name(%__MODULE__{name: name}, _default) when is_binary(name) and name != "",    do: name
  def get_account_name(%__MODULE__{name: nil},  default)  when is_binary(default),                do: default
  def get_account_name(%__MODULE__{original_user: %{email: email}}, _default),                    do: email
  def get_account_name(%__MODULE__{original_user: %Ecto.Association.NotLoaded{}, original_user_id: user_id}, _default) do
    case Backend.Projections.User.get_user(user_id) do
      %{email: email} -> email
      _ -> ""
    end
  end
  def get_account_name(_, _), do: ""
end
