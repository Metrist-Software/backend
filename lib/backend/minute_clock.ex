defmodule Backend.MinuteClock do
  @moduledoc """
  A Clock driver for a clock that ticks every minute. Also has a utility function to return the current
  minute for code that is driven by this clock.

  A minute represents a nice balance between overloading the event store with `Domain.Clock.Ticked` events
  and scheduling that is too coarse-grained and should work for most of our time-related things.
  """
  use Task, restart: :permanent

  require Logger

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(arg) do
    with true <- function_exported?(Backend.App, :__info__, 1) do
      Backend.App.dispatch(%Domain.Clock.Tick{id: name(), value: current_minute()})
    else
      _ ->
        Logger.warn("Backend.App not loaded, not dispatching Tick. Waiting a few seconds (live_reload most likely)")
        Process.sleep(30_000)
    end
    # We run fast so we never will miss ticks. The cost of doing this is negligible as
    # the command is idempotent and the singleton instance is already in memory.
    Process.sleep(1_000)
    run(arg)
  end

  # Public API

  def name, do: "minute-clock"

  @doc """
  Returns the current minute as an integer.
  """
  def current_minute, do: DateTime.utc_now() |> DateTime.to_unix() |> div(60)
  def current_second, do: DateTime.utc_now() |> DateTime.to_unix()

  @doc """
  Returns the minute when X hours or days have elapsed. This can be used to schedule timeouts without
  having to make explicit calculations.
  """
  def plus(1, :second),  do: plus(1, :seconds)
  def plus(n, :seconds), do: ceil((current_second() + n) / 60)
  def plus(1, :hour), do:  plus(1, :hours)
  def plus(n, :hours), do: current_minute() + (60 * n)
  def plus(1, :day), do:   plus(1, :days)
  def plus(n, :days), do:  plus(n * 24, :hours)
  def plus(1, :week), do:  plus(1, :weeks)
  def plus(n, :weeks), do: plus(n * 7, :days)
end
