defmodule Backend.EventStoreRewriter.MigrationV2Test do
  use ExUnit.Case, async: true

  alias Backend.EventStoreRewriter.Migrations.EventsV2

  test "snapshots are dropped" do
    event = %Domain.Account.Events.SnapshotStored{data: nil, name: "foo", id: "42"}

    assert {[], :dummy} == EventsV2.handle_event(%{data: event}, :dummy)
  end

  test "old telemetry gets discarded" do
    event = %Domain.Monitor.Events.TelemetryAdded{
      id: "42_Fake",
      account_id: "42",
      check_logical_name: "dummy",
      monitor_logical_name: "Fake",
      instance_name: "test",
      created_at: NaiveDateTime.utc_now(),
      value: 123.45,
      is_private: false
    }

    events = [
      %{data: event},
      %{
        data: %Domain.Monitor.Events.TelemetryAdded{
          event
          | created_at: ~N[2021-01-01 12:00:00.444],
            id: "too_old"
        }
      }
    ]

    results = Enum.map(events, &EventsV2.handle_event(&1, :dummy))

    assert [
             {[%{data: ^event}], _},
             {[], _}
           ] = results
  end

  test "old event clears get discarded" do
    event = %Domain.Monitor.Events.EventsCleared{
      id: "42_Fake",
      account_id: "42",
      monitor_logical_name: "Fake",
      end_time: NaiveDateTime.utc_now()
    }

    events = [
      %{data: event},
      %{
        data: %Domain.Monitor.Events.EventsCleared{
          event
          | end_time: ~N[2021-01-01 12:55:00.444],
            id: "too_old"
        }
      }
    ]

    results = Enum.map(events, &EventsV2.handle_event(&1, :dummy))

    assert [
             {[%{data: ^event}], _},
             {[], _}
           ] = results
  end

  test "old clock ticks get discarded" do
    event = %Domain.Clock.Ticked{
      id: "TestClock",
      value: Backend.MinuteClock.current_minute()
    }

    # Too high so that it is certainly too old
    minutes_per_year = 400 * 24 * 60

    events = [
      %{data: event},
      %{
        data: %Domain.Clock.Ticked{
          event
          | id: "TooOld",
            value: event.value - minutes_per_year
        }
      }
    ]

    results = Enum.map(events, &EventsV2.handle_event(&1, :dummy))

    assert [
             {[%{data: ^event}], _},
             {[], _}
           ] = results
  end

  defmodule FakeMigration do
    defmodule FakeEventStore do
      def link_to_stream(stream, :any_version, [event_id], name: name, conn: conn) do
        send(self(), {:link_to_stream, stream, event_id, name, conn})
        :ok
      end
    end
    defmodule FakeApp do
      def config() do
        [event_store: [event_store: FakeEventStore]]
      end
    end

    def name, do: "FakeMigration"
    def app, do: FakeApp
    def event_store, do: FakeEventStore
  end

  test "Typestream linking is done" do
    event = %Domain.Account.Events.Created{id: "test_account"}

    EventsV2.after_append_batch_to_stream(
      [%{data: event, event_id: "fake_id"}, %{data: event, event_id: "again_fake"}],
      FakeMigration,
      :fake_conn
    )

    # One call for each event.
    assert_received {:link_to_stream, "TypeStream.Elixir.Domain.Account.Events.Created",
                     "fake_id", "FakeMigration", :fake_conn}
    assert_received {:link_to_stream, "TypeStream.Elixir.Domain.Account.Events.Created",
                     "again_fake", "FakeMigration", :fake_conn}
  end
end
