defmodule Backend.Notifications.SlackHandler do
  @event_type Domain.NotificationChannel.Events.attempt_type("slack")

  use Backend.Notifications.Handler,
    event_type: @event_type

  @impl true
  def get_response(req) do
    Backend.Integrations.Slack.post_message(req)
  end

  @impl true
  def make_request(_event, %Backend.Projections.Dbpa.Alert{is_instance_specific: true}), do: :skip
  def make_request(event, alert) do
    workspace_id =
      event.channel_extra_config
      |> Map.get(:WorkspaceId)

    message =
      Map.get(alert.formatted_messages, "slack", "")
      |> maybe_do_team_id_replacement(workspace_id)

    workspace_token =
      workspace_id
      |> Backend.Projections.get_slack_token()

    %{token: workspace_token, channel: event.channel_identity, text: "", blocks: message}
  end

  @impl true
  def response_ok?({:ok, _}), do: true
  def response_ok?(_), do: false

  @impl true
  def response_status_code({:ok, _}), do: 200
  def response_status_code(_), do: 500

  # left public for test
  @doc false
  def maybe_do_team_id_replacement(slack_message, workspace_id) when is_nil(workspace_id), do: slack_message
  def maybe_do_team_id_replacement(slack_message, workspace_id) when is_list(slack_message) do
    # If we have a list of blocks, let's just encode it all to a string, replace every occurrence and then decode it back
    slack_message
    |> Jason.encode!()
    |> maybe_do_team_id_replacement(workspace_id)
    |> Jason.decode!()
  end
  def maybe_do_team_id_replacement(slack_message, workspace_id) when is_binary(slack_message) do
    String.replace(slack_message, "--TEAM_ID--", workspace_id)
  end
end
