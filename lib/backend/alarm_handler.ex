defmodule Backend.MemsupAlarmHandler do
  require Logger

  def init(_arg) do
    Logger.info("MemsupAlarmHandler attached")
    {:ok, %{}}
  end

  def handle_event({:set_alarm, {:process_memory_high_watermark, pid}}, alarms)
      when is_pid(pid) do
    info = Process.info(pid)
    pd = to_process_details(pid)

    Logger.warn(
      "MemsupAlarmHandler process_memory_high_watermark for process #{inspect(pid)}/#{inspect(pd)}: #{inspect(info)}"
    )

    # We have observed LiveView channels getting themselves in a knot. For now, kill them,
    # we can inspect logfiles later. Ideally we'd do things like dump its state, but we've
    # seen these processes with huge queue backlogs and that means that even killing is not
    # guaranteed to be successful, let alone fetching state.
    if String.contains?(pd.name_or_initial_call, "LiveView.Channel") do
      Logger.error(
        "MemsupAlarmHandler process is a LiveView Channel, this should not happen, killing"
      )

      Process.exit(pid, :kill)
    end

    {:ok, alarms}
  end

  def handle_event({:system_memory_high_watermark, []}, state) do
    Logger.warn("MemsupAlarmHandler system_memory_high_watermark fired")
    {:ok, state}
  end

  def handle_event(event, state) do
    Logger.info("MemsupAlarmHandler unhandled event #{inspect(event)}")
    {:ok, state}
  end

  # Shameless copy/paste from LiveView Dashboard
  #
  def to_process_details(pid) do
    {name, initial_call} =
      case Process.info(pid, [:initial_call, :dictionary, :registered_name]) do
        [{:initial_call, initial_call}, {:dictionary, dictionary}, {:registered_name, name}] ->
          initial_call = Keyword.get(dictionary, :"$initial_call", initial_call)
          name = if is_atom(name), do: inspect(name), else: format_initial_call(initial_call)
          {name, initial_call}

        _ ->
          {nil, nil}
      end

    %{name_or_initial_call: name, initial_call: initial_call}
  end

  defp format_initial_call({:supervisor, mod, arity}), do: Exception.format_mfa(mod, :init, arity)
  defp format_initial_call({m, f, a}), do: Exception.format_mfa(m, f, a)
  defp format_initial_call(nil), do: nil
end
