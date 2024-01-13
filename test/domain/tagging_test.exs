defmodule Domain.TaggingTest do
  use ExUnit.Case, async: true

  alias Domain.Tagging

  test "legacy vs standard tagging" do
    assert Tagging.is_legacy?("gcp")
    refute Tagging.is_legacy?("vendor:gcp")
  end

  test "validity checking" do
    assert Tagging.is_valid?("vendor:gcp")
    assert Tagging.is_valid?("metrist:group:subtype:value")
    refute Tagging.is_valid?("gcp")
    refute Tagging.is_valid?("thi/s:shouldnot:have:that:slash:in:the:key")
  end

  test "splitting into key and value pairs" do
    assert {"vendor", "gcp"} = Tagging.kv("vendor:gcp")
    assert {"my:sub:key", "value?123"} = Tagging.kv("my:sub:key:value?123")
  end
end
