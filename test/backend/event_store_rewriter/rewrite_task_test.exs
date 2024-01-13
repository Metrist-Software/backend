defmodule Backend.EventStoreRewriter.RewriteTaskTest do
  use ExUnit.Case, async: true

  defmodule FakeApp do
    def config() do
      [event_store: [event_store: FakeStore]]
    end
  end

  defmodule Event.A do
    defstruct [:a]
  end

  defmodule Event.B do
    defstruct [:b]
  end

  defmodule Event.C do
    defstruct [:c]
  end

  defmodule SimpleMigration do
    use Backend.EventStoreRewriter.Migration,
      name: "simple",
      app: FakeApp
  end

  test "Simple migration should copy all events" do
    events = [
      %{data: %Event.A{}},
      %{data: %Event.B{}},
      %{data: %Event.C{}}
    ]

    migrated_events =
      events
      |> run_test_migration(SimpleMigration)
      |> only_events()

    assert migrated_events == events
  end

  defmodule DropMigration do
    use Backend.EventStoreRewriter.Migration,
      name: "drop",
      app: FakeApp

    drop(Backend.EventStoreRewriter.RewriteTaskTest.Event.A)
    drop(Backend.EventStoreRewriter.RewriteTaskTest.Event.B)
  end

  test "drop command should not copy selected events" do
    events = [
      %{data: %Event.A{}},
      %{data: %Event.B{}},
      %{data: %Event.C{}},
      %{data: %Event.A{}},
      %{data: %Event.B{}},
      %{data: %Event.C{}}
    ]

    migrated_events =
      events
      |> run_test_migration(DropMigration)
      |> only_events()

    assert migrated_events == [%{data: %Event.C{}}, %{data: %Event.C{}}]
  end

  defmodule LastMigration do
    use Backend.EventStoreRewriter.Migration,
      name: "last",
      app: FakeApp

    def handle_event(event, state) do
      state = Map.put(state, :last, event)
      {[], state}
    end

    def handle_last(:last, event) do
      [event]
    end
  end

  test "basic state handling works" do
    events = [
      %{data: %Event.C{c: 1}},
      %{data: %Event.B{}},
      %{data: %Event.C{c: 2}}
    ]

    migrated_events =
      events
      |> run_test_migration(LastMigration)
      |> only_events()

    assert migrated_events == [%{data: %Event.C{c: 2}}]
  end

  test "chunks emitted have the correct accumulator state" do
    events = [
      %{data: %Event.A{}},
      %{data: %Event.B{}},
      %{data: %Event.C{}}
    ]

    [chunk | _] =
      events
      |> Stream.chunk_every(2)
      |> Backend.EventStoreRewriter.RewriteTask.transform_chunks(%{}, LastMigration)
      |> Stream.take(1)
      |> Enum.to_list()

    assert chunk == {[], %{last: %{data: %Event.B{}}}}
  end

  defmodule CountAMigration do
    use Backend.EventStoreRewriter.Migration,
      name: "count_a",
      app: FakeApp

    def handle_event(%{data: %Event.A{}}, state) do
      state = Map.update(state, :sum, 1, fn cur -> cur + 1 end)
      {[], state}
    end

    def handle_last(:sum, state) do
      [%{data: %{sum: state}}]
    end
  end

  test "restarts work correctly" do
    original_events = [
      %{data: %Event.A{}},
      %{data: %Event.B{}},
      %{data: %Event.A{}},
      %{data: %Event.A{}},
      %{data: %Event.B{}},
      %{data: %Event.A{}},
      %{data: %Event.C{}}
    ]

    # First run of two events
    [{events, acc} | _] =
      original_events
      |> Stream.chunk_every(2)
      |> Backend.EventStoreRewriter.RewriteTask.transform_chunks(%{}, CountAMigration)
      |> Stream.take(1)
      |> Enum.to_list()

    assert events == [%{data: %Event.B{}}]
    assert acc == %{sum: 1}

    # Run the rest of the events with the current accumulator (simulating a restart)
    chunks =
      original_events
      |> Enum.drop(2)
      |> Stream.chunk_every(2)
      |> Backend.EventStoreRewriter.RewriteTask.transform_chunks(acc, CountAMigration)
      |> Enum.to_list()

    events = Enum.flat_map(chunks, fn {events, _acc} -> events end)

    assert events == [
      %{data: %Event.B{}},
      %{data: %Event.C{}},
      %{data: %{sum: 4}}
    ]
  end

  defp run_test_migration(events, migration) do
    events
    |> Stream.chunk_every(2)
    |> Backend.EventStoreRewriter.RewriteTask.transform_chunks(%{}, migration)
    |> Enum.to_list()
  end

  defp only_events(accs_and_events) do
    Enum.flat_map(accs_and_events, fn {events, _acc} -> events end)
  end
end
