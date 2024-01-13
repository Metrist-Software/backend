defmodule Domain.CryptUtilsTest do
  use ExUnit.Case, async: true

  defmodule TestEvent do
    use Domain.CryptUtils, fields: [:encrypt, :nullfield]
    defstruct [:id, :encrypt, :nullfield, :clear]

  end

  test "Encrypt basics" do
    event = %TestEvent{id: "123", encrypt: "this stuff", clear: "not this stuff"}
    encrypted = Domain.CryptUtils.encrypt(event, "test")
    refute String.starts_with?(encrypted.id, "@enc@:")
    assert String.starts_with?(encrypted.encrypt, "@enc@:")
    refute String.starts_with?(encrypted.clear, "@enc@:")

    decrypted = Domain.CryptUtils.decrypt(encrypted)
    assert decrypted.id == event.id
    assert decrypted.encrypt == event.encrypt
    assert decrypted.clear == event.clear
    assert decrypted.nullfield == event.nullfield
  end

  test "Maps are encrypted" do
    event = %TestEvent{id: "123", encrypt: %{key: "value", nested: %{key: "value"}}, clear: "not this stuff"}
    encrypted = Domain.CryptUtils.encrypt(event, "test")
    assert String.starts_with?(encrypted.encrypt.key, "@enc@:")
    assert String.starts_with?(encrypted.encrypt.nested.key, "@enc@:")

    decrypted = Domain.CryptUtils.decrypt(encrypted)
    assert decrypted.encrypt.key == "value"
    assert decrypted.encrypt.nested.key == "value"
  end

  test "Encryption padding works" do
    id = "fake_id"
    value = "this is a test"
    scheme = :aes_256_cbc
    Enum.each(1..10_000, fn i ->
      key = Domain.CryptUtils.gen_random(Domain.CryptUtils.key_bytes(scheme))
      encrypted = Domain.CryptUtils.encrypt_field(value, id, scheme, key)
      [_marker, _id, iv, length, cipher] = String.split(encrypted, ":")
      decrypted = Domain.CryptUtils.do_decrypt({nil, Atom.to_string(scheme), key}, iv, cipher)
      decrypted = Kernel.binary_part(decrypted, 0, String.to_integer(length))
      if decrypted != value do
        # In case this bombs, print the data we need to replicatethis.
        IO.inspect(i, label: "counter")
        IO.inspect(key, label: "key")
        IO.inspect(encrypted, label: "encrypted")
        IO.inspect(decrypted, label: "decrypted")
        IO.inspect(String.to_charlist(decrypted), label: "decrypted")
        IO.inspect(String.to_charlist(value), label: "value")
      end
      assert decrypted == value
     end)
  end
end
