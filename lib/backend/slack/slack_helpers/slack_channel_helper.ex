defmodule Backend.Slack.SlackHelpers.SlackChannelHelper do

  require Logger

  @channel_name_pattern ~r/<#(?<channel_id>(?i)c.+)\|(?<channel_name>.*)>/

  def is_channel_valid?(_channel = nil) do
    false
  end

  def is_channel_valid?(channel) do
    String.match?(channel, @channel_name_pattern)
  end

  # "deconstructs" escaped form <c1234|general> into tuple {C1234, #general}
  def get_channel(id_and_name) do
    map = Regex.named_captures(@channel_name_pattern, id_and_name)
    id = map
    |> Map.get("channel_id")
    |> String.upcase()
    map = Map.replace(map, "channel_id", id)
    Map.get(map, "channel_name")
    |> maybe_add_channel_name(map)
  end

  defp maybe_add_channel_name(_channel_name = "", map) do
    { Map.get(map, "channel_id"), nil } # for private channels
  end

  defp maybe_add_channel_name(channel_name, map) do
    { Map.get(map, "channel_id"), "#" <> channel_name }
  end

end
