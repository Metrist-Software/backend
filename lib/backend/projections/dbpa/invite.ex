defmodule Backend.Projections.Dbpa.Invite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "invites" do
    field :invitee_id, :string
    field :inviter_id, :string
    field :accepted_at, :naive_datetime_usec

    timestamps()
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:id, :invitee_id, :invitee_email, :inviter_id])
    |> validate_required([:id, :invitee_id, :invitee_email, :inviter_id])
  end

  import Ecto.Query
  alias Backend.Repo
  alias Domain.User

  def list_invites(account_id) do
    Repo.all(__MODULE__, prefix: Repo.schema_name(account_id))
  end

  def list_invites_with_emails(account_id) do
    query = from i in __MODULE__,
      join: invitee in User, prefix: "public", on: invitee.id == i.invitee_id,
      join: inviter in User, prefix: "public", on: inviter.id == i.inviter_id,
      select: %{
        id: i.id,
        invitee_id: invitee.id,
        invitee_email: invitee.email,
        inviter_id: inviter.id,
        inviter_email: inviter.email
      }

    query
      |> put_query_prefix(Repo.schema_name(account_id))
      |> Repo.all()
  end

  def get_invite!(id, account_id) do
    Repo.get!(__MODULE__, id, prefix: Repo.schema_name(account_id))
  end

  def get_invites_for_user(user_id, account_id) do
    (from c in __MODULE__,
      where: c.invitee_id == ^user_id)
    |> Repo.all(prefix: Repo.schema_name(account_id))
  end

end
