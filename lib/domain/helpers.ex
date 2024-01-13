defmodule Domain.Helpers do
  @moduledoc """
  Miscellaneous utilities around domain modules
  """

  @doc """
  Given an event struct, return the "bare" entity name. This assumes that the
  event struct has a type named "Domain.<Entity>.Events.<EventName>"
  """
  def entity_of(%{__struct__: type}) do
    entity_of(type)
  end

  def entity_of(entity) when is_atom(entity) do
    entity
    |> Atom.to_string() # Note: this prefixes with "Elixir."
    |> String.split(".")
    |> Enum.at(2) # ["Elixir", "Domain", "<Entity>", ...]
  end

  @doc """
  Given a command struct, return the indicated event struct. A bit dirty and
  will only work well if both have the same fields, enforcemet, etc. Caveat Emptor!
  """
  def make_event(command, event_type) do
    Map.put(command, :__struct__, event_type)
  end

  @doc """
  Constant for shared account
  """
  def shared_account_id, do: "SHARED"

  @doc """
  Given two lists of maps, merges them into a single list based on the given field.
  Overwrites entries in the first list with entries from the second that have the
  same value in the given field
  """
  @spec merge_on_field([map()], [map()], atom()) :: [map()]
  def merge_on_field(shared, nil, _field), do: shared
  def merge_on_field(nil, account, _field), do: account
  def merge_on_field(shared, account, field) do
    account ++
     Enum.reject(shared, fn c -> Enum.any?(account, &(Map.get(&1, field) == Map.get(c, field))) end)
  end

  def id_of(event, field_name) do
    case Map.get(event, field_name) do
      nil ->
        # Old style event, the id is the config id
        event.id
      config_id ->
        # New style event, the config_id is the config id
        config_id
    end
  end
end
