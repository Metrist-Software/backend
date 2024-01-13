defmodule Backend.Plugins.Beam do
  @moduledoc """
  BEAM telemetry in addition to `PromEx.Plugins.Beam`
  """
  use PromEx.Plugin

  @metric_prefix [:backend, :beam]

  @impl true
  def manual_metrics(_opts) do
    [
      beam_system_info()
    ]
  end

  def beam_system_info do
    Manual.build(
      :beam_system_info,
      {__MODULE__, :execute_beam_system_info, []},
      [
        last_value(
          @metric_prefix ++ [:system, :time, :offset],
          event_name: @metric_prefix ++ [:system, :time, :offset],
          description: "Current time offset between Erlang monotonic time and Erlang system time in native time unit"
        )
      ]
    )
  end

  def execute_beam_system_info do
    :telemetry.execute(
      @metric_prefix ++ [:system, :time, :offset],
      %{offset: :erlang.time_offset},
      %{}
    )
  end
end
