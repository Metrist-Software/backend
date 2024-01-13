defmodule Backend.Slack.SlackHelpers.SlackMessageHelpers do
  require Logger

  @spec post_message_to_user(%Backend.Projections.User{}, String.t, any) :: any
  def post_message_to_user(user, message, blocks) do
    case user.last_seen_slack_user_id do
      nil -> Logger.debug("#{inspect user} is not a slack user.")
      _ ->
        case Backend.Projections.get_slack_workspace(user.last_seen_slack_team_id) do
          nil -> Logger.debug("Workspace with id #{user.last_seen_slack_team_id} not associated.")
          workspace -> Backend.Integrations.Slack.post_message(workspace.access_token, user.last_seen_slack_user_id, message, blocks)
        end
    end
  end

  @spec send_new_monitor_message(%Backend.Projections.User{}, %Backend.Projections.Dbpa.Monitor{}) :: any
  def send_new_monitor_message(user, monitor) do
    text_only_message = "You've added #{monitor.name} to your account. You can now subscribe to notifications for this monitor via channel subscriptions using \"/metrist subscriptions <CHANNEL_NAME>\" or via DM notifications using \"/metrist notifications\". You can also request status of this monitor using \"/metrist #{monitor.logical_name}\"";
    blocks = [%{ "type" => "section", "text" => %{ "type" => "mrkdwn", "text" => String.replace(text_only_message, "\"", "`") }}]
    post_message_to_user(user, text_only_message, blocks)
  end

  def send_app_home_welcome_message(slack_workspace, channel) do
    {text_only_message, blocks} = get_welcome_message_parts()
    Backend.Integrations.Slack.post_message(slack_workspace.access_token, channel, text_only_message, blocks)
  end

  defp get_welcome_message_parts() do
    topics = [
      "Welcome to Metrist! Get started with the following actions.",
      "*Check a Service*\nSee which services we're monitoring and check their status with `/metrist`",
      "*Get Details*\nDeep dive into the status of a service using `/metrist <monitor-name> details`",
      "*Get Notified*\nGet notified of outages and degradations as soon as they're found. Setup personal DM alerts with `/metrist notifications` or subscribe a channel to alerts with `/metrist subscriptions <channel-name>`",
      "*Explore Metrist*\nSee everything you can do with `/metrist help`"
      ]

      text_only_message =
        topics
        |> Enum.reduce("", fn topic, acc ->
          topic =
            topic
            |> String.replace("`", "\"")
            |> String.replace("*", "")
          acc <> topic <> "\n"
        end)

      blocks =
        topics
        |> Enum.map(fn topic ->
          %{ "type" => "section", "text" => %{ "type" => "mrkdwn", "text" => topic}}
        end)

      {text_only_message, blocks}
  end
end
