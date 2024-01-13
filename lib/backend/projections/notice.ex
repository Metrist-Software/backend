defmodule Backend.Projections.Notice do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "notices" do
    field :monitor_id, :string
    field :summary, :string
    field :description, :string
    field :end_date, :naive_datetime

    many_to_many :user_reads, Backend.Projections.User,
      join_through: Backend.Projections.NoticeRead

    timestamps()
  end

  import Ecto.Query
  alias Backend.Repo

  def active_notices_by_monitor_id(monitor_id) do
    (from notice in __MODULE__)
    |> where_notice_for_monitor(monitor_id)
    |> where_notice_active()
    |> Repo.all()
  end

  def active_notices_for_user(user_id) do
    read_notices = (from notice_read in Backend.Projections.NoticeRead, where: notice_read.user_id == ^user_id, select: notice_read.notice_id)

    (from notice in __MODULE__, where: notice.id not in subquery(read_notices))
    |> where_notice_for_monitor(nil)
    |> where_notice_active()
    |> Repo.all()
  end

  def active_notices() do
    (from notice in __MODULE__)
    |> where_notice_active()
    |> Repo.all()
  end

  defp where_notice_for_monitor(query, nil), do: where(query, [n], is_nil(n.monitor_id))
  defp where_notice_for_monitor(query, monitor_id), do: where(query, [n], n.monitor_id == ^monitor_id)

  defp where_notice_active(query) do
    now = NaiveDateTime.utc_now()

    query
    |> where([n], n.end_date > ^now or is_nil(n.end_date))
  end
end
