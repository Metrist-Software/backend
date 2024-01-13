defmodule Backend.JsonUtilsTest do
  use ExUnit.Case, async: true

  test "Can be Jason encoded" do
    ts = %TestStruct{id: 123, timestamp: ~N[1901-02-03 04:05:06.777]}
    js = Jason.encode!(ts)

    assert js == ~s({"id":123,"timestamp":"1901-02-03T04:05:06.777"})
  end

  test "Can be deserialized by Commanded" do
    ts = %TestStruct{id: 123, timestamp: ~N[1901-02-03 04:05:06.777]}
    js = Jason.encode!(ts)

    ds = Commanded.Serialization.JsonSerializer.deserialize(js, type: Atom.to_string(TestStruct))

    assert ts == ds
  end

  test "Date/Time parsing works" do
    assert ~N[1901-02-03 04:05:06.777] == Backend.JsonUtils.maybe_time_from("1901-02-03T04:05:06.777")
    assert nil == Backend.JsonUtils.maybe_time_from(nil)
    assert nil == Backend.JsonUtils.maybe_time_from("Garbage in, nil out")
  end
end
