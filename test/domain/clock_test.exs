defmodule Domain.ClockTest do
  use ExUnit.Case, async: true

  alias Domain.Clock

  test "New clock just starts ticking" do
    assert %Clock.Ticked{id: "minute", value: 42} == Clock.execute(%Clock{}, %Clock.Tick{id: "minute", value: 42})
  end

  test "New value emits a tick" do
    assert %Clock.Ticked{id: "minute", value: 43} == Clock.execute(%Clock{id: "minute", value: 42}, %Clock.Tick{id: "minute", value: 43})
  end

  test "Duplicate ticks are discarded" do
    assert nil == Clock.execute(%Clock{id: "minute", value: 42}, %Clock.Tick{id: "minute", value: 42})
  end

  test "Time only goes forward" do
    assert nil == Clock.execute(%Clock{id: "minute", value: 42}, %Clock.Tick{id: "minute", value: 41})
  end

  test "New clock is correctly updated" do
    assert %Clock{id: "minute", value: 42} == Clock.apply(%Clock{}, %Clock.Ticked{id: "minute", value: 42})
  end

  test "Existing clock is correctly updated" do
    assert %Clock{id: "minute", value: 43} == Clock.apply(%Clock{id: "minute", value: 42}, %Clock.Ticked{id: "minute", value: 43})
  end
end
