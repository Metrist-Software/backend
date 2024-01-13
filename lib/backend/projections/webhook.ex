defmodule Backend.Projections.Webhook do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "webhooks" do
    field :monitor_logical_name, :string
    field :instance_name, :string
    field :data, :string
    field :content_type, :string

    timestamps(type: :utc_datetime_usec)
  end

  def store(monitor_logical_name, instance_name, data, content_type) do
    Backend.Repo.insert!(%__MODULE__{
      id: Domain.Id.new(),
      monitor_logical_name: monitor_logical_name,
      instance_name: instance_name,
      data: data,
      content_type: content_type
    })
  end

  import Ecto.Query
  alias Backend.Repo

  def find(uid, monitor_logical_name, instance_name) do
    # have to a do full like here as these webhooks can be in any format
    # we will only look at ones aded within the last 10 minutes for a given monitor
    # and instance. inserted_at, logical_name, instance_name are indexed so this
    # should remain fast
    like = "%#{uid}%"
    since = NaiveDateTime.utc_now() |> Timex.shift(minutes: -10)

    __MODULE__
    |> where([w], w.inserted_at >= ^since)
    |> where([w], w.monitor_logical_name == ^monitor_logical_name)
    |> where([w], w.instance_name == ^instance_name or w.instance_name == "any")
    |> where([w], like(w.data, ^like))
    |> order_by([w], [desc: w.inserted_at])
    |> limit(1)
    |> Repo.one()
  end
end
