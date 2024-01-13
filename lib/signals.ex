defmodule Signals do

  def start() do
    :gen_event.swap_handler(:erl_signal_server, {:erl_signal_handler, []}, {__MODULE__, []})
  end

  def init(_args) do
    IO.puts("Signals: Initializing signal handling")
    {:ok, []}
  end

  def handle_event(exit, state) when exit in [:sigterm, :sigusr1] do
    IO.puts("Signals: Asked to terminate by #{exit}")
    :init.stop()
    {:ok, state}
  end

  def handle_event(event, state) do
    IO.puts("Signals: Unhandled signal: #{inspect event}")
    {:ok, state}
  end
end
