defmodule Domain.Flow.TimeoutProcessTest do
  use ExUnit.Case, async: true

  alias Domain.Clock.Ticked
  alias Domain.Flow.Events
  alias Domain.Flow.TimeoutProcess

  test "When we create a flow, we register it with its timeout" do
    event = %Events.Created{id: "123", name: "test", timeout_minute: 27535029, steps: []}
    assert TimeoutProcess.interested?(event)

    # Starting a flow does not result in any commands
    assert [] = TimeoutProcess.handle(%TimeoutProcess{}, event)

    # .. but does register the flow with its timeout
    new_pm = TimeoutProcess.apply(%TimeoutProcess{}, event)
    assert new_pm.entries == %{"123" => 27535029}
  end

  test "When we terminate a flow, we remove it if registered" do
    event = %Events.FlowCompleted{id: "123"}
    pm = %TimeoutProcess{entries: %{"abc" => 92, "123" => 1, "456" => 13}}
    assert TimeoutProcess.interested?(event)

    # Handling this does not emit any commands
    assert [] = TimeoutProcess.handle(pm, event)

    # .. but it does remove the entry
    new_pm = TimeoutProcess.apply(pm, event)
    assert new_pm.entries == %{"456" => 13, "abc" => 92}
  end

  test "When a tick arrives, we emit timeout commands for overdue flows and remove them" do
    event = %Ticked{id: Backend.MinuteClock.name(), value: 100}
    pm = %TimeoutProcess{entries: %{"abc" => 101, "123" => 99, "456" => 100}}
    assert TimeoutProcess.interested?(event)

    commands = TimeoutProcess.handle(pm, event)
    assert [
      %Domain.Flow.Commands.Timeout{id: "123"},
      %Domain.Flow.Commands.Timeout{id: "456"}
    ] == commands

    new_pm = TimeoutProcess.apply(pm, event)
    assert new_pm.entries == %{"abc" => 101}
  end
end
