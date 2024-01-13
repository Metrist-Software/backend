defmodule Backend.LogFilter do
  @moduledoc """
  Simple module to filter out some logger messages
  """

  # Only pattern match on :warning level messages so this doesn't end up being too expensive.
  # Everything else will just pass through with :ignore
  # Have to use a log filter here as filtering out all warn messages from commanded_eventstore
  # or all logging entirely from commanded_eventstore woudln't be what we want.
  defp ignore_link_duplicate_event_filter(%{level: :warning, msg: {:string, msg}}, _) do
    if :unicode.characters_to_binary(msg) == "Failed to link events to stream due to: :duplicate_event" do
      :stop
    else
      :ignore
    end
  end
  defp ignore_link_duplicate_event_filter(_, _), do: :ignore

  def setup_filters() do
    :logger.add_primary_filter(:ignore_link_duplicate_event, {&ignore_link_duplicate_event_filter/2, []})
  end
end
