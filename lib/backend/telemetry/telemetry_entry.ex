defmodule Backend.Telemetry.TelemetryEntry do
  use Ecto.Schema
  @primary_key false
  import Ecto.Changeset

  schema "monitor_telemetry" do
    field :account_id, :string
    field :check_id, :string
    field :instance_id, :string
    field :monitor_id, :string
    field :time, :utc_datetime_usec
    field :value, :float
  end

  @doc false
  def changeset(telemetry_entry, attrs) do
    telemetry_entry
    |> cast(attrs, [:time, :monitor_id, :account_id, :instance_id, :check_id, :value])
    |> validate_required([:time, :monitor_id, :account_id, :instance_id, :check_id, :value])
  end
end
