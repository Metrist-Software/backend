defmodule Backend.Projections.NotificationChannel.RetryProcess do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "notification_retry_process" do
    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def register(id) do
    %__MODULE__{id: id}
    |> Repo.insert(on_conflict: :nothing)
  end

  def deregister(id) do
    (from p in __MODULE__, where: p.id == ^id)
    |> Repo.delete_all()
  end

  def all_ids do
    (from p in __MODULE__, select: p.id)
    |> Repo.all()
  end
end
