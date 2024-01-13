defmodule BackendWeb.ApiHelperTest do
  use ExUnit.Case, async: true
  alias BackendWeb.ApiHelpers

  describe "get_daterange_from_params/1" do
    test "Always returns utc" do
      params = %{"from" => "2022-11-28T19:00:00+03:00", "to" => nil}
      {from, _to} = ApiHelpers.get_daterange_from_params(params)
      assert from == ~N[2022-11-28T16:00:00]
    end

    test "Handles nil values for from or to" do
      params = %{"from" => "2022-11-28T00:00:00Z", "to" => nil}
      {from, to} = ApiHelpers.get_daterange_from_params(params)
      assert is_nil(to)
      assert not is_nil(from)
    end
  end
end
