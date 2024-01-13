defmodule Domain.CryptUtils do
  @moduledoc """
  Encryption/descryption stuff.
  """
  @marker "@enc@"

  @doc """
  Returns the currently active scheme for new keys
  """
  def current_scheme, do: :aes_256_cbc

  defmacro __using__(fields: fields) do
    encs =
      Enum.map(fields, fn f ->
        quote do
          e = Map.put(e, unquote(f), fun.(Map.get(e, unquote(f))))
        end
      end)

    quote do
      def __cryptutils_crypt(e, fun) do
        unquote_splicing(encs)
        e
      end
    end
  end

  # Note that "owner_type" is mostly informational. Our ids are unique enough,
  # so just using that would be plenty of information. One step more would then
  # to simply reuse the owner id as the primary key of the keys table. So there
  # might be a bit of YAGNI going on here.

  @doc """
  Encrypt an event for the specified owner type. The event id is used as owner id.
  """
  def encrypt(event, owner_type) do
    encrypt(event, owner_type, event.id)
  end

  @doc """
  Encrypt an event for the specified owner type with the specified owner id.
  """
  def encrypt(event, owner_type, owner_id) do
    {id, scheme, key} = Domain.CryptRepo.current().key_for(owner_type, owner_id)
    scheme = String.to_atom(scheme)

    event.__struct__.__cryptutils_crypt(event, fn v ->
      case v do
        nil -> nil
        v -> encrypt_field(v, id, scheme, key)
      end
    end)
  end

  @doc """
  Decrypt an event. The encrypted fields will be decrypted with the keys stored in
  the curently active repository.
  """
  def decrypt(event) do
    event.__struct__.__cryptutils_crypt(event, fn v ->
      case v do
        nil -> nil
        v -> decrypt_field(v)
      end
    end)
  end

  defp decode(external) do
    external
    |> Base62.decode!()
    |> :binary.encode_unsigned()
  end

  defp decode(external, expected_bytes) do
    # Random numbers may start with a 0 and the encoding above will slice that off. So we
    # pad left with zeros and take as many bytes on the right as we need.
    decoded = decode(external)
    binary_pad_left(decoded, expected_bytes)
  end

  # Public for testing, not meant to be used directly.
  def encrypt_field(m, id, scheme, key) when is_map(m) do
    # For a map, we encrypt all the values.
    m
    |> Enum.map(fn {k, v} -> {k, encrypt_field(v, id, scheme, key)} end)
    |> Map.new()
  end

  def encrypt_field("", _id, _scheme, _key), do: ""
  def encrypt_field(nil, _id, _scheme, _key), do: nil

  def encrypt_field(value, id, scheme, key) do
    iv = gen_random(iv_bytes(scheme))
    real_key = decode(key, key_bytes(scheme))
    real_iv = decode(iv, iv_bytes(scheme))

    real_encrypted =
      :crypto.crypto_one_time(scheme, real_key, real_iv, value, encrypt: true, padding: :random)

    encrypted =
      real_encrypted
      |> :binary.decode_unsigned()
      |> Base62.encode()

    "#{@marker}:#{id}:#{iv}:#{String.length(value)}:#{encrypted}"
  end

  def decrypt_field(nil), do: nil

  def decrypt_field(maybe_encrypted_field) when is_map(maybe_encrypted_field) do
    maybe_encrypted_field
    |> Enum.map(fn {k, v} -> {k, decrypt_field(v)} end)
    |> Map.new()
  end

  def decrypt_field(maybe_encrypted_field) do
    # Note: this is currently a tad expensive :) TODO cache keys in ETS
    [maybe_marker | fields] = String.split(maybe_encrypted_field, ":")

    case maybe_marker do
      @marker ->
        [id, iv, length, encrypted] = fields
        length = String.to_integer(length)
        f = decrypt_field(id, iv, encrypted, length)
        :binary.part(f, 0, length)

      _ ->
        maybe_encrypted_field
    end
  end

  defp decrypt_field(_id, _iv, _encrypted, 0), do: ""

  defp decrypt_field(id, iv, encrypted, _len) do
    case Domain.CryptRepo.current().get(id) do
      nil ->
        "<missing key #{id}>"

      key = {_i, _s, _k} ->
        do_decrypt(key, iv, encrypted)
    end
  end

  def do_decrypt({_id, scheme, key}, iv, encrypted) do
    scheme = String.to_atom(scheme)
    real_key = decode(key, key_bytes(scheme))
    real_iv = decode(iv, iv_bytes(scheme))
    real_encrypted = decode(encrypted)
    real_encrypted_size = :erlang.byte_size(real_encrypted)
    # Left pad our encrypted data to a full block
    block_size = block_size(scheme)

    real_encrypted =
      case Integer.mod(real_encrypted_size, block_size) do
        0 ->
          # Round block, we can use it as is
          real_encrypted

        _ ->
          # Left pad up to the next round block size
          padded_size = (div(real_encrypted_size, block_size) + 1) * block_size
          binary_pad_left(real_encrypted, padded_size)
      end

    real_decrypted =
      :crypto.crypto_one_time(
        scheme,
        real_key,
        real_iv,
        real_encrypted,
        encrypt: false,
        padding: :random
      )

    real_decrypted
  end

  defp iv_bytes(scheme) do
    :crypto.cipher_info(scheme).iv_length
  end

  def key_bytes(scheme) do
    :crypto.cipher_info(scheme).key_length
  end

  def block_size(scheme) do
    :crypto.cipher_info(scheme).block_size
  end

  def gen_random(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
    |> Base62.encode()
  end

  defp binary_pad_left(decoded, expected_bytes) do
    bit_size = expected_bytes * 8
    padded = <<0::size(bit_size), decoded::binary>>
    :binary.part(padded, {byte_size(padded), -expected_bytes})
  end
end
