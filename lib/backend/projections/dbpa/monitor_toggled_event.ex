defmodule Backend.Projections.Dbpa.MonitorToggledEvent do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "monitor_toggled_events" do
    field :monitor_logical_name, :string
    field :state, Ecto.Enum, values: Backend.Projections.Dbpa.Snapshot.states()

    timestamps()
  end
end
