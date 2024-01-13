defmodule Backend.EventStoreRewriter.MigrationState do
  @moduledoc """
  Migration state. We stash this in the snapshot table in the
  target schema.
  """
  use TypedStruct

  alias EventStore.Snapshots.SnapshotData

  typedstruct do
    @derive Jason.Encoder
    field :last_event_number, non_neg_integer()
    field :accumulator, map()
    field :migration_name, atom() | nil
  end

  @doc """
  Read the stored state.
  """
  def read(event_store, name) do
    case event_store.read_snapshot(id(), name: name) do
      {:ok, %SnapshotData{data: data}} ->
        %__MODULE__{
          data |
          migration_name: String.to_existing_atom(data.migration_name)
        }

      {:error, _} ->
        %__MODULE__{
          last_event_number: 0,
          accumulator: %{},
          migration_name: nil
        }
    end
  end

  @doc """
  Write the stored state.
  """
  def write(event_store, name, event_number, accumulator, migration_name) do
    snapshot = %SnapshotData{
      source_uuid: id(),
      source_version: 0,
      source_type: Atom.to_string(__MODULE__),
      data: %__MODULE__{
        last_event_number: event_number,
        accumulator: accumulator,
        migration_name: migration_name
      },
      metadata: %{}
    }

    event_store.record_snapshot(snapshot, name: name)
  end

  defp id(), do: "#{__MODULE__}/state"
end
