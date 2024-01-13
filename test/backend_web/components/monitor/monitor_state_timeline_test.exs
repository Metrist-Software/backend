defmodule BackendWeb.Components.Monitor.MonitorStateTimelineTest do
  alias BackendWeb.Components.Monitor.MonitorStateTimeline
  use ExUnit.Case, async: true

  describe "MonitorStateTimeline.group_state_changes/2" do
    test "groups changes into one hour interval if timeframe is 3 days" do
      state_changes = [
        %{
          date: ~U[2022-03-20 07:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 07:05:00Z],
          state: :down
        },
        %{
          date: ~U[2022-03-20 08:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 10:00:00Z],
          state: :up
        }
      ]

      result = MonitorStateTimeline.group_state_changes(state_changes, 3)

      assert Map.keys(result) == [
               ~U[2022-03-20 07:00:00Z],
               ~U[2022-03-20 08:00:00Z],
               ~U[2022-03-20 10:00:00Z]
             ]
    end

    test "groups changes into 8-hour interval if timeframe is 30 days" do
      state_changes = [
        %{
          date: ~U[2022-03-20 07:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 07:05:00Z],
          state: :down
        },
        %{
          date: ~U[2022-03-20 08:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 10:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 11:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 23:00:00Z],
          state: :up
        }
      ]

      result = MonitorStateTimeline.group_state_changes(state_changes, 30)

      assert Map.keys(result) == [
               ~U[2022-03-20 00:00:00Z],
               ~U[2022-03-20 08:00:00Z],
               ~U[2022-03-20 16:00:00Z]
             ]
    end

    test "groups changes into 1-hour interval if timeframe is 90 days" do
      state_changes = [
        %{
          date: ~U[2022-03-20 07:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-20 07:05:00Z],
          state: :down
        },
        %{
          date: ~U[2022-03-21 08:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-21 10:00:00Z],
          state: :up
        },
        %{
          date: ~U[2022-03-22 11:00:00Z],
          state: :up
        }
      ]

      result = MonitorStateTimeline.group_state_changes(state_changes, 90)

      assert Map.keys(result) == [
               ~U[2022-03-20 00:00:00Z],
               ~U[2022-03-21 00:00:00Z],
               ~U[2022-03-22 00:00:00Z]
             ]
    end
  end

  describe "MonitorStateTimeline.make_map_of_worst_and_final_state_by_date/1" do
    test "Picks the worst and final state of a state changes group" do
      state_change_group = %{
        ~U[2022-03-20 07:00:00Z] => [
          %{date: ~U[2022-03-20 07:00:00Z], state: :up},
          %{date: ~U[2022-03-20 07:05:00Z], state: :down}
        ],
        ~U[2022-03-20 08:00:00Z] => [
          %{date: ~U[2022-03-20 08:00:00Z], state: :down},
          %{date: ~U[2022-03-20 08:05:00Z], state: :up}
        ]
      }

      assert MonitorStateTimeline.make_map_of_worst_and_final_state_by_date(state_change_group) ==
               %{
                 ~U[2022-03-20 07:00:00Z] => %{worst: :down, final: :down},
                 ~U[2022-03-20 08:00:00Z] => %{worst: :down, final: :up}
               }
    end
  end
end
