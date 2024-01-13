defmodule TestCryptRepo do
  @behaviour Domain.CryptRepo

  @scheme :aes_256_cbc

  @key {
    "test_key_id",
    "#{@scheme}",
    Domain.CryptUtils.gen_random(Domain.CryptUtils.key_bytes(@scheme))
  }

  @impl true
  def initialize(), do: :ok

  @impl true
  def key_for(_owner_type, _owner_id) do
    @key
  end

  @impl true
  def get(id) do
    {_id, scheme, key} = @key
    {id, scheme, key}
  end
end
