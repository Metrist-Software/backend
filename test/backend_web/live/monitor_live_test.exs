defmodule BackendWeb.MonitorsLiveTest do
  use ExUnit.Case, async: true

  describe "Snapshot handling" do
    setup do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          displayed_monitors: %{
            "test" => %{
              logical_name: "test",
              snapshot: %{
                state: :up
              }
            }
          },
          current_user: %{
            account_id: "42"
          },
          __changed__: nil
        }
      }

      get_snapshot = fn
        "42", "test" -> :new_snapshot
        acc, mon -> flunk("Unexpected arguments on get snapshot: (#{acc}, #{mon})")
      end

      [
        socket: socket,
        get_snapshot: get_snapshot
      ]
    end

    test "When receiving an update message, the correct snapshot is updated", context do
      socket = context.socket

      socket =
        BackendWeb.MonitorsLive.update_snapshot(socket, "test", :down, :displayed_monitors, context.get_snapshot)

      new_mon = Map.get(socket.assigns.displayed_monitors, "test")
      assert :new_snapshot == new_mon.snapshot
    end

    test "When receiving an update message and the state doesn't change, no update is made", context do
      socket = context.socket

      socket =
        BackendWeb.MonitorsLive.update_snapshot(socket, "test", :up, :displayed_monitors, context.get_snapshot)

      new_mon = Map.get(socket.assigns.displayed_monitors, "test")
      assert :new_snapshot != new_mon.snapshot
    end
  end
end
