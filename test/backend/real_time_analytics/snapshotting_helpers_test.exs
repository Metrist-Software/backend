defmodule Backend.RealTimeAnalytics.SnapshottingHelpersTest do
  use ExUnit.Case, async: true

  alias Backend.Projections.Dbpa.Snapshot.CheckDetail
  alias Backend.RealTimeAnalytics.SnapshottingHelpers

  describe "did_state_transition?/2" do
    test "nil to up should be false without outstanding events" do
      value = SnapshottingHelpers.did_state_transition?(nil, %{state: :up}, [])
      assert value == false
    end

    test "nil to not up should be true without outstanding events" do
      value = SnapshottingHelpers.did_state_transition?(nil, %{state: :degraded}, [])
      assert value == true

      value = SnapshottingHelpers.did_state_transition?(nil, %{state: :down}, [])
      assert value == true
    end

    test "nil to state should use outstanding events" do
      states = [:up, :degraded, :issues, :down]

      for from <- states do
        for to <- states do
          should_transition = from != to
          assert SnapshottingHelpers.did_state_transition?(nil, %{state: to}, [{"", "", "", "", from}]) == should_transition
        end
      end
    end

    test "nil to blocked state should always be false" do
      assert SnapshottingHelpers.did_state_transition?(nil, %{state: :blocked}, []) == false
      assert SnapshottingHelpers.did_state_transition?(%{state: :up}, %{state: :blocked}, []) == false
    end

    test "Changing state should be true" do
      states = [:up, :degraded, :issues, :down]

      for from <- states do
        for to <- states do
          should_transition = from != to
          assert SnapshottingHelpers.did_state_transition?(%{state: from}, %{state: to}, []) == should_transition
        end
      end
    end
  end

  test "combine_check_details" do
    previous = [
      %CheckDetail{check_id: "a", instance: "a", average: 123.0},
      %CheckDetail{check_id: "b", instance: "a", average: 123.0}
    ]

    current = [
      %CheckDetail{check_id: "a", instance: "a", average: 321.0},
      %CheckDetail{check_id: "b", instance: "b", average: 321.0}
    ]

    combined = SnapshottingHelpers.combine_check_details(previous, current)

    assert Enum.count(combined) == 2

    assert combined[{"b", "a"}] == nil
    assert combined[{"a", "a"}] != nil
    assert combined[{"b", "b"}] != nil

    assert combined[{"a", "a"}].previous == %CheckDetail{
             check_id: "a",
             instance: "a",
             average: 123.0
           }

    assert combined[{"a", "a"}].current == %CheckDetail{
             check_id: "a",
             instance: "a",
             average: 321.0
           }

    assert combined[{"b", "b"}].previous == nil

    assert combined[{"b", "b"}].current == %CheckDetail{
             check_id: "b",
             instance: "b",
             average: 321.0
           }
  end
end
