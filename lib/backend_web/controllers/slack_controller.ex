defmodule BackendWeb.SlackController do
  use BackendWeb, :controller

  require Logger

  use TypedStruct

  alias Backend.Slack.SlackCommands
  alias Backend.Slack.SlashCommand
  alias Backend.Slack.SlackInteractionHandler
  alias Backend.Slack.SlackInteractionHandler.{
    SlackInteraction,
    SlackUser,
    SlackInteractionAction,
    SlackInteractionOption,
    SlackInteractionOptionText
  }

  @moduledoc """
  Receives incoming webhooks and user commands/interactions from Slack
  """

  def post_webhook(conn, %{"type" => "url_verification", "challenge" => challenge}) do
    text(conn, challenge)
  end

  def post_webhook(conn, %{"type" => "event_callback", "event" => %{"type" => "app_home_opened", "tab" => "messages", "channel" => channel, "user" => user}, "team_id" => team_id}) do
    maybe_send_app_home_welcome(Backend.Projections.SlackWorkspace.get_slack_workspace(team_id), channel, user)
    send_resp(conn, 200, "")
  end

  def post_webhook(conn, %{"type" => "event_callback", "event" => %{"type" => "app_uninstalled"}, "team_id" => team_id}) do
    case Backend.Projections.SlackWorkspace.get_slack_workspace(team_id) do
      %{account_id: account_id} ->
        cmd = %Domain.Account.Commands.RemoveSlackWorkspace{
          id: account_id,
          team_id: team_id
        }
        Backend.App.dispatch(cmd)
      nil -> nil
    end

    send_resp(conn, 200, "")
  end

  def post_webhook(conn,  %{"type" => "event_callback", "event" => %{"type" => type}} = e) do
    Logger.info("Received unrecognized slack event webhook of type #{type}. #{inspect e}")
    send_resp(conn, 200, "")
  end

  def post_command(%{body_params: body} = conn, _params) do
    team_id = body["team_id"]
    case Backend.Projections.get_slack_workspace(team_id) do
      nil ->
        Logger.info("SLACK POST COMMAND: team ID #{team_id} is invalid")
        conn
        |> send_resp(403, ~s({"error": "Forbidden"}))
        |> halt()
      workspace ->

        sc = %SlashCommand{
          token: body["token"],
          team_id: team_id,
          team_domain: body["team_domain"],
          enterprise_id: body["enterprise_id"],
          enterprise_name: body["enterprise_name"],
          channel_id: body["channel_id"],
          channel_name: body["channel_name"],
          user_id: body["user_id"],
          username: body["user_name"],
          command: body["command"],
          text: body["text"] |> String.trim(),
          response_url: body["response_url"],
          trigger_id: body["trigger_id"],
          account_id: workspace.account_id
          }

        output_text = SlackCommands.execute(sc)
        conn
        |> json(output_text)
      end
  end

  def post_interact(conn, _params) do
    Jason.decode!(conn.params["payload"])
    |> maybe_interact(conn)
  end

  defp maybe_interact(nil, conn) do
    Logger.info("SLACK INTERACT: 400 Bad Request")
    conn
    |> send_resp(400, ~s({"error": "Bad Request"}))
    |> halt()
  end

  defp maybe_interact(%{ "actions" => payload_actions, "user" => payload_user, "type" => type, "response_url" => response_url }, conn) do
    action = make_interaction_action(hd(payload_actions))

    case Backend.Projections.get_slack_workspace(payload_user["team_id"]) do
      nil ->
        conn
        |> send_resp(403, ~s({"error": "Forbidden"}))
        |> halt()
      workspace ->
        interaction =
          %SlackInteraction{
            action: action,
            action_type: action.action_id |> String.split(" ") |> hd(),
            account_id: workspace.account_id,
            type: type,
            response_url: response_url,
            actions: make_actions_list(payload_actions),
            user: make_user(payload_user)
          }

        output_text = SlackInteractionHandler.execute(interaction)
        body = Jason.encode!(output_text)

        headers = [{"Content-type", "application/json"}]
        HTTPoison.post(
          interaction.response_url,
          body,
          headers
        )

        send_resp(conn, 200, "")
    end
  end

  defp make_actions_list(actions) do
    Enum.reduce(actions, [], fn i, list ->
      [make_interaction_action(i) | list]
    end)
    |> Enum.reverse()
  end

  defp make_interaction_action(action) do
    %SlackInteractionAction{
      type: action["type"],
      action_id: action["action_id"],
      selected_option: maybe_set_selected_option(action),
      selected_options: maybe_set_selected_options(action),
      value: action["value"]
    }
  end

  defp maybe_set_selected_option(%{"selected_option" => selected_option}) do
    make_interaction_option(selected_option["text"], selected_option["value"])
  end

  defp maybe_set_selected_option(_action) do
    []
  end

  defp maybe_set_selected_options(%{"selected_options" => selected_options}) do
    make_selected_options_list(selected_options)
  end

  defp maybe_set_selected_options(_action) do
    []
  end

  defp make_selected_options_list(selected_options) do
    Enum.reduce(selected_options, [], fn s, list ->
      [make_interaction_option(s["text"], s["value"]) | list]
    end)
    |> Enum.reverse()
  end

  defp make_interaction_option(text, value) do
    %SlackInteractionOption{
      text: make_interaction_option_text(text),
      value: value
    }
  end

  defp make_interaction_option_text(text) do
    %SlackInteractionOptionText{
      type: text["type"],
      text: text["text"],
      emoji: text["emoji"]
    }
  end

  defp make_user(user) do
    %SlackUser{
      id: user["id"],
      username: user["username"],
      name: user["name"],
      team_id: user["team_id"]
    }
  end

  defp maybe_send_app_home_welcome(nil, _channel, _user), do: nil
  defp maybe_send_app_home_welcome(%{access_token: access_token} = workspace, channel, user) do
    with  {:ok, history} <- Backend.Integrations.Slack.conversation_history(access_token, channel, 1) do
      if (length(history.messages) <= 0) do
        Logger.info("Sending slack home welcome message to user #{user} on workspace with id #{workspace.id}")
        Backend.Slack.SlackHelpers.SlackMessageHelpers.send_app_home_welcome_message(
          workspace,
          channel
        )
      end
    else
      {:error, "missing_scope"} ->
        Logger.warn("We don't have the im:history scope on workspace with id #{workspace.id}")
      {:error, error} ->
        Logger.warn("Error getting im history for workspace with id #{workspace.id}. Error: #{inspect error}")
    end
    :ok
  end
end
