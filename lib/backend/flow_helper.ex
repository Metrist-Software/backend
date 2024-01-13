defmodule Backend.FlowHelper do
  @moduledoc """
  Some simple helper functions to make flow-invoking code in
  our controllers/views a it less intrusive.
  """

  alias Domain.Flow.Commands

  # We expect a flow to finish in four hours by default.
  # Note that this should be shorter than our session time, normally.
  @default_timeout_s 4 * 3_600

  @doc """
  Start a new flow, returns the id of the flow (to be used in later
  step complete invocations).

  Steps should be an array of strings for the flow code but can be an array
  of anything here, it get converted on the fly. Code that uses atoms may read
  a bit better so using them is fine.
  """
  def start_flow(name, steps, timeout \\ @default_timeout_s) do
    timeout_tick = Backend.MinuteClock.current_minute() + round(timeout / 60)
    cmd = %Commands.Create{
      id: Domain.Id.new(),
      name: name,
      timeout_minute: timeout_tick,
      steps: Enum.map(steps, &"#{&1}")
    }

    Backend.App.dispatch_with_actor(actor(), cmd)

    cmd.id
  end

  @doc """
  Step the flow forward.
  """
  def step_complete(id, step_name) do
    cmd = %Commands.Step{
      id: id,
      step: "#{step_name}"
    }
    Backend.App.dispatch_with_actor(actor(), cmd)

    :ok
  end

  defp actor, do: Backend.Auth.Actor.backend_code()
end
