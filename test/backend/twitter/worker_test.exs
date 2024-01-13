defmodule Backend.Twitter.WorkerTest do
  use ExUnit.Case, async: true

  alias Backend.Twitter.Worker
  alias Domain.Monitor.Commands

  defmodule DepMod do
    def utc_now, do: ~N[2020-01-01T12:00:00.000]
    def count_tweets("bar", ~N[2020-01-01T11:45:00.000]), do: 42

    def dispatch_with_actor(_, %Commands.AddTwitterCount{} = cmd), do: send(self(), cmd)
  end

  @deps %{
    twitter_client: DepMod,
    commanded_app: DepMod,
    ndt_source: DepMod
  }

  test "Run tick while starting empty" do
    state = %Worker.State{
      monitor_logical_name: "foo",
      hashtag: "bar",
      counts: []
    }

    {:noreply, state} = Worker.handle_info(:tick, state, @deps)

    assert_received(%Commands.AddTwitterCount{
      id: "SHARED_foo",
      hashtag: "bar",
      bucket_end_time: ~N[2020-01-01T12:00:00.000],
      bucket_duration: 900,
      count: 42
    })

    assert state.counts == [{1_577_880_000, 42}]
  end

  test "Buckets are added in order" do
    state = %Worker.State{
      monitor_logical_name: "foo",
      hashtag: "bar",
      counts: [{1234, 56789}]
    }

    {:noreply, state} = Worker.handle_info(:tick, state, @deps)

    assert state.counts == [{1234, 56789}, {1_577_880_000, 42}]
  end

  test "We drop the oldest bucket on overflow" do
    # 96 buckets of counts on the wall...
    counts = for i <- 0..95, do: {i, 100 * i}
    state = %Worker.State{
      monitor_logical_name: "foo",
      hashtag: "bar",
      counts: counts
    }

    {:noreply, state} = Worker.handle_info(:tick, state, @deps)

    assert Enum.count(state.counts) == 96
    assert Enum.at(state.counts, 0) == {1, 100}
    assert Enum.at(state.counts, 1) == {2, 200}
    # ...
    assert Enum.at(state.counts, 94) == {95, 9500}
    assert Enum.at(state.counts, 95) == {1_577_880_000, 42}
   end

 end
