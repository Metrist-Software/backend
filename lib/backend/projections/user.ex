defmodule Backend.Projections.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "users" do
    field :account_id, :string
    field :email, :string
    field :uid, :string
    field :last_seen_slack_team_id, :string
    field :last_seen_slack_user_id, :string
    field :is_metrist_admin, :boolean
    field :is_read_only, :boolean
    field :hubspot_contact_id, :string
    field :last_login, :naive_datetime_usec
    field :timezone, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:id, :account_id, :email, :uid, :last_seen_slack_team_id, :last_seen_slack_user_id, :is_metrist_admin, :is_read_only, :hubspot_contact_id, :last_login, :timezone])
    |> validate_required([:id, :email, :uid])
  end

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Projections.Dbpa.Invite

  def active_web_user_count(:daily), do: do_active_web_user_count(NaiveDateTime.utc_now() |> Timex.shift(days: -1))
  def active_web_user_count(:weekly), do: do_active_web_user_count(NaiveDateTime.utc_now() |> Timex.shift(weeks: -1))
  def active_web_user_count(:monthly), do: do_active_web_user_count(NaiveDateTime.utc_now() |> Timex.shift(months: -1))
  defp do_active_web_user_count(since) do
    __MODULE__
    |> where([u], u.last_login >= ^since)
    |> Repo.aggregate(:count)
  end

  def list_users_with_invites(account_id) do
    query = from u in __MODULE__, prefix: "public",
      left_join: invite in Invite, on: invite.invitee_id == u.id,
      left_join: inviter in __MODULE__, prefix: "public", on: inviter.id == invite.inviter_id,
      where: u.account_id == ^account_id or (is_nil(u.account_id) and not is_nil(invite) and is_nil(invite.accepted_at)),
      select: %{
        id: u.id,
        email: u.email,
        uid: u.uid,
        invite_id: invite.id,
        inviter_id: inviter.id,
        inviter_email: inviter.email,
        invite_accepted_at: invite.accepted_at,
        invited_at: invite.inserted_at
      }

    query
      |> put_query_prefix(Repo.schema_name(account_id))
      |> Repo.all()
  end

  def list_users do
    __MODULE__
    |> Repo.all()
  end

  def list_users_for_account(account_id) do
    __MODULE__
    |> with_account_id(account_id)
    |> Repo.all()
  end

  def get_user!(id), do: Repo.get!(__MODULE__, id)

  def get_user(id), do: Repo.get(__MODULE__, id)

  def user_by_email(email) do
    __MODULE__
    |> with_email(email)
    |> Repo.one()
  end

  defp with_account_id(query, nil), do: query
  defp with_account_id(query, account_id) do
    query
    |> where([u], u.account_id == ^account_id)
  end

  defp with_email(query, nil), do: query
  defp with_email(query, email) do
    query
    |> where([u], u.email == ^email)
  end
end
