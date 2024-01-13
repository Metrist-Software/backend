defmodule BackendWeb.MonitorLiveTest do
  use ExUnit.Case, async: true

  test "Most recently checked is in the right order" do
    dates = [~N[2021-11-15 19:41:02.295887], ~N[2021-11-15 19:21:44.434548],  ~N[2021-11-15 19:41:02.29588]]
    most_recent = BackendWeb.MonitorDetailLive.most_recent_date(dates)

    assert most_recent == Enum.at(dates, 0)
  end
end
