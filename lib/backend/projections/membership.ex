defmodule Backend.Projections.Membership do
  use Ecto.Schema

  # Kept here to keep package names central. These are billed
  # straight through Stripe:
  @stripe_plans ["team", "business"]

  @primary_key {:id, :string, []}
  schema "memberships" do
    field :tier, Ecto.Enum, values: [:free, :team, :business, :enterprise]
    field :billing_period, Ecto.Enum, values: [:monthly, :yearly]
    field :start_date, :naive_datetime
    field :end_date, :naive_datetime

    belongs_to :account, Backend.Projections.Account, foreign_key: :account_id, references: :id, type: :string

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def all_active_for_account(account_id) do
    account_id
    |> active_memberships_query()
    |> Repo.all()
  end

  def active_memberships_query() do
    now = NaiveDateTime.utc_now()
    from m in __MODULE__,
      where: m.start_date < ^now
             and (m.end_date > ^now or is_nil(m.end_date))
  end

  def active_memberships_query(nil), do: active_memberships_query()
  def active_memberships_query(account_id) do
    now = NaiveDateTime.utc_now()
    from m in __MODULE__,
      where: m.account_id == ^account_id
             and m.start_date < ^now
             and (m.end_date > ^now or is_nil(m.end_date))
  end

  def stripe_plans, do: @stripe_plans
end
