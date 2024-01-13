defmodule Backend.Projectors.EctoTest do
  use ExUnit.Case, async: true

  import Backend.Projectors.Ecto, only: [dt_with_default_from_meta: 2]

  # Pretty much more documentation than a "proper" test to
  # stress that event metadata has regular datetimes and
  # we work mostly wth naive datetimes.
  test "date with default" do
    meta_dt = ~U[2022-04-08 18:13:52.729262Z]
    meta = Support.CommandedHelpers.fake_metadata(%{created_at: meta_dt})
    now = NaiveDateTime.utc_now()
    meta_ndt = DateTime.to_naive(meta_dt)

    assert meta_ndt == dt_with_default_from_meta(nil, meta)
    assert now == dt_with_default_from_meta(now, meta)
  end
end
