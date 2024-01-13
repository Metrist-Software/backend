defmodule Domain.NoticeTest do
  use ExUnit.Case, async: true

  test "Can't process commands without a create" do
    user = %Domain.Notice{}
    cmd = %Domain.Notice.Commands.Clear{id: "42"}

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, :no_create_command_seen} == Domain.Notice.execute(user, cmd)
    end)
  end
end
