defmodule Backend.MonitorAgeTelemetryTest do
  use ExUnit.Case, async: true

  alias Backend.MonitorAgeTelemetry, as: MAT

  test "Age when monitor has never been seen is starting age of server" do
    gmc = make_gmc()
    start = NaiveDateTime.utc_now()
    start_clock = fn -> start end

    later = NaiveDateTime.add(start, 60, :second)
    later_clock = fn -> later end

    with {:ok, state, _} <- MAT.init(nil),
         {:noreply, state} <- MAT.do_handle_continue(state, gmc, start_clock),
         {:reply, ages, _state} <- MAT.do_ages(state, gmc, later_clock) do

      # Ages are relative, the number of `interval_secs` periods since last run.
      assert ages == [{"mln", 1.0}, {"mln2", 2.0}]
    end
  end

  test "Observations are processed correctly" do
    gmc = make_gmc()
    start = NaiveDateTime.utc_now()
    start_clock = fn -> start end

    observation = NaiveDateTime.add(start, 30, :second)

    later = NaiveDateTime.add(start, 60, :second)
    later_clock = fn -> later end

    event = %{
      # This just to circumvent type checking so we don't need to list all the mandatory fields
      __struct__: Domain.Monitor.Events.TelemetryAdded,
      monitor_logical_name: "mln",
      created_at: observation,
      instance_name: nil
    }

    with {:ok, state, _} <- MAT.init(nil),
         {:noreply, state} <- MAT.do_handle_continue(state, gmc, start_clock),
         {:noreply, state} <- MAT.handle_cast({:telemetry, event}, state),
         {:reply, ages, _state} <- MAT.do_ages(state, gmc, later_clock) do

      # Through the observation, "mln" now has an age of half a period.
      assert ages == [{"mln", 0.5}, {"mln2", 2.0}]
    end
  end

  test "We collect a separate metric for instances" do
    start = NaiveDateTime.utc_now()
    start_clock = fn -> start end

    gain = fn "SHARED" -> ["my-region", "other-region"] end

    observation = NaiveDateTime.add(start, 30, :second)

    later = NaiveDateTime.add(start, 60, :second)
    later_clock = fn -> later end

    event = %{
      __struct__: Domain.Monitor.Events.TelemetryAdded,
      monitor_logical_name: "mln",
      created_at: observation,
      instance_name: "my-region"
    }

    with {:ok, state, _} <- MAT.init(nil),
         {:noreply, state} <- MAT.do_handle_continue(state, fn _ -> [] end, start_clock),
         {:noreply, state} <- MAT.handle_cast({:telemetry, event}, state),
         {:reply, ages, _state} <- MAT.do_instances(state, gain, later_clock) do

      assert ages == [{"my-region", 30}, {"other-region", 60}]
    end
  end

  test "Telemetry is executed correctly" do
    me = self()
    fake_server = spawn_link(&fake_server/0)
    fake_telemetry = fn prefix, telem, tags -> send me, {prefix, telem, tags} end

    MAT.execute_metrics(fake_server, fake_telemetry)

    assert_received {[:backend, :monitor_age], %{relative_age: 1.0}, %{monitor: :mln}}
    assert_received {[:backend, :monitor_age], %{instance_age: 60.0}, %{instance: :"my-region"}}
  end

  defp fake_server do
    # Ok, this is maybe a tad dirty. This is essentially how a genserver call works
    # and saves us from having to use the whole `use Genserver` dance...
    receive do
      {:"$gen_call", {_from, [:alias | alias] = tag}, :ages} ->
        send alias, {tag, [{"mln", 1.0}]}
        fake_server()
      {:"$gen_call", {_from, [:alias | alias] = tag}, :instances} ->
        send alias, {tag, [{"my-region", 60.0}]}
        fake_server()
      msg ->
        # Should not happen.
        IO.puts("Unexpected: #{inspect msg}")
    end
  end

  test "Events update state correctly" do
    observation = NaiveDateTime.utc_now()

    # This time we do use the whole struct so we can verify we're using the
    # correct field names.
    event = %Domain.Monitor.Events.TelemetryAdded{
      monitor_logical_name: "mln",
      created_at: observation,
      instance_name: "my-region",
      id: nil,
      account_id: nil,
      check_logical_name: nil,
      value: nil,
      is_private: nil,
      metadata: nil
    }

    with {:ok, state, _} <- MAT.init(nil),
         {:noreply, state} <- MAT.do_handle_continue(state, fn _ -> [] end),
         {:noreply, state} <- MAT.handle_cast({:telemetry, event}, state) do

      assert state.monitor_times == %{"mln" => observation}
      assert state.instance_times == %{"my-region" => observation}
    end
  end

  test "Errors update state correctly" do
    observation = NaiveDateTime.utc_now()

    event = %Domain.Monitor.Events.ErrorAdded{
      monitor_logical_name: "mln",
      time: observation,
      instance_name: "my-region",
      message: nil,
      check_logical_name: nil,
      account_id: nil,
      error_id: nil,
      id: nil
    }

    with {:ok, state, _} <- MAT.init(nil),
         {:noreply, state} <- MAT.do_handle_continue(state, fn _ -> [] end),
         {:noreply, state} <- MAT.handle_cast({:error, event}, state) do

      assert state.monitor_times == %{"mln" => observation}
      assert state.instance_times == %{"my-region" => observation}
    end
  end

  defp make_gmc, do:
    fn "SHARED" ->
      [
        %Backend.Projections.Dbpa.MonitorConfig{
          monitor_logical_name: "mln",
          interval_secs: 60
        },
        %Backend.Projections.Dbpa.MonitorConfig{
          monitor_logical_name: "mln2",
          interval_secs: 30
        }
      ]
    end
end
