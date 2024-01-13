defmodule Domain.FlowTest do
  use ExUnit.Case, async: true
  alias Domain.Flow
  alias Domain.Flow.{Commands,Events}

  test "On creation, no steps have been completed" do
    event = Flow.execute(%Flow{}, %Commands.Create{
          id: "123",
          name: "test",
          timeout_minute: 27535029,
          steps: ["get out of bed", "dress", "breakfast", "brush teeth", "leave for work"]
    })
    assert event.id == "123"
    assert event.name == "test"
    assert event.timeout_minute == 27535029
    assert length(event.steps) == 5

    flow = Flow.apply(%Flow{}, event)
    assert flow.id == "123"
    assert length(flow.steps) == 5
    assert flow.completed == 0
  end

  test "Stepping increments step count only if it is the next step" do
    flow = %Flow{id: "123", steps: ["1", "2", "3"], completed: 0}
    event = Flow.execute(flow, %Commands.Step{id: "123", step: "1"})
    assert %Events.StepCompleted{} = event
    assert event.completed == 1
    assert event.step == "1"

    flow = Flow.apply(flow, event)
    assert flow.completed == 1

    flow = %Flow{id: "123", steps: ["1", "2", "3"], completed: 1}
    assert nil == Flow.execute(flow, %Commands.Step{id: "123", step: "1"})

    flow = %Flow{id: "123", steps: ["1", "2", "3"], completed: 1}
    assert nil == Flow.execute(flow, %Commands.Step{id: "123", step: "32"})

  end

  test "On the last step, the flow is complete" do
    flow = %Flow{id: "123", steps: ["1", "2", "3"], completed: 2}
    events = Flow.execute(flow, %Commands.Step{id: "123", step: "3"})

    assert length(events) == 2
    [step_completed, flow_completed] = events

    assert step_completed.id == "123"
    assert step_completed.completed == 3
    assert step_completed.step == "3"

    assert flow_completed.id == "123"

    # We don't need to do anything special for a completed flow. It will simply
    # stop accepting steps
    new_flow = Flow.apply(flow, step_completed)
    new_flow = Flow.apply(new_flow, flow_completed)
    assert nil == Flow.execute(new_flow, %Commands.Step{id: "123", step: "4"})
  end

  test "A flow can also complete through a timeout" do
    flow = %Flow{id: "123", steps: ["1", "2", "3"], completed: 1}
    event = Flow.execute(flow, %Commands.Timeout{id: "123"})

    assert event.at_step == 1

    # And a timed-out flow also stops stepping.
    new_flow = Flow.apply(flow, event)
    assert nil == Flow.execute(new_flow, %Commands.Step{id: "123", step: "2"})
  end

  # TODO time the deltas between steps?
end
