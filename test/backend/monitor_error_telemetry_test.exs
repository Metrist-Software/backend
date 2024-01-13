defmodule Backend.MonitorErrorTelemetryTest do
  use ExUnit.Case, async: true

  alias Backend.MonitorErrorTelemetry

  test "Test GenServer basics" do
    name = Domain.Id.new() |> String.to_atom()
    {:ok, _pid} = Backend.MonitorErrorTelemetry.start_link([], name)
    make_error = fn monitor_id ->
      %Domain.Monitor.Commands.AddError{
        id: monitor_id,
        error_id: "ignored",
        check_logical_name: "ignored",
        instance_name: "ignored",
        message: "ignored",
        report_time: "ignored",
        is_private: false
      }
   end

    MonitorErrorTelemetry.register_error(make_error.("SHARED_one"), name)
    MonitorErrorTelemetry.register_error(make_error.("SHARED_one"), name)
    MonitorErrorTelemetry.register_error(make_error.("SHARED_two"), name)

    # Counts are correct
    counts = GenServer.call(name, :errors)
    assert counts == %{"SHARED_one" => 2, "SHARED_two" => 1}

    # Counts are reset after a call.
    counts = GenServer.call(name, :errors)
    assert counts == %{}
  end
end
