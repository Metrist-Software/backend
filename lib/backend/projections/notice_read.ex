defmodule Backend.Projections.NoticeRead do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "notice_reads" do
    belongs_to :user, Backend.Projections.User, type: :string
    belongs_to :notice, Backend.Projections.Notice, type: :string

    timestamps()
  end
end
