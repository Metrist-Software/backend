defmodule Backend.Crypto.EctoRepo do
  @doc """
  Repository that stores key information in Ecto.
  """
  @behaviour Domain.CryptRepo
  import Ecto.Query

  @impl true
  def initialize(), do: :ok

  @impl true
  def key_for(owner_type, id) do
    q =
      from k in "keys",
        where:
          k.owner_type == ^owner_type and
            k.owner_id == ^id and
            k.is_default == true,
        select: {k.id, k.scheme, k.key}

    case Backend.Repo.one(q) do
      nil -> create_key_for(owner_type, id)
      key -> key
    end
  end

  @impl true
  def get(id) do
    Backend.Repo.get(Backend.Crypto.Key, id)
  end

  defp create_key_for(owner_type, id) do
    scheme = Domain.CryptUtils.current_scheme()

    key = %Backend.Crypto.Key{
      id: Domain.Id.new(),
      is_default: true,
      owner_id: id,
      owner_type: owner_type,
      scheme: Atom.to_string(scheme),
      key: Domain.CryptUtils.gen_random(Domain.CryptUtils.key_bytes(scheme))
    }

    Backend.Repo.insert(key)
    {key.id, key.scheme, key.key}
  end
end
