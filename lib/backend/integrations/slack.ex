defmodule Backend.Integrations.Slack do
  @moduledoc """
  Code that is actually responsible for talking to Slack.
  """

  require Logger


  @scope [
           "chat:write",
           "chat:write.public",
           "commands",
           "im:history"
         ]
         |> Enum.join(",")

  @doc """
  Return the OAuth2 URL to start authorizing with Slack
  """
  @spec slack_oauth_url(String.t, String.t) :: String.t
  def slack_oauth_url(state_id, redirect_to) do
    client_id = Application.get_env(:backend, :slack_client_id)

    query =
      [
        client_id: client_id,
        scope: @scope,
        state: state_id,
        redirect_uri: redirect_to
      ]
      |> URI.encode_query()

    "https://slack.com/oauth/v2/authorize?#{query}"
  end

  @doc """
  Given a auth code, fetch bot connection data
  """
  @spec get_app_access_token(String.t, String.t) :: map
  def get_app_access_token(code, redirect_uri) do
    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.post(
      "https://slack.com/api/oauth.v2.access",
      {:form, [
          client_id: Application.get_env(:backend, :slack_client_id),
          client_secret: Application.get_env(:backend, :slack_client_secret),
          code: code,
          redirect_uri: redirect_uri
        ]})
    Jason.decode!(body, keys: :atoms)
  end

  @spec post_message(binary(), binary(), binary(), []) :: {:ok, any()} | {:error, any()}
  def post_message(opts) do
    post_message(opts.token, opts.channel, opts.text, opts.blocks)
  end

  def post_message(token, channel, text, nil) do
    do_post_message(token, channel, [text: text])
  end

  def post_message(token, channel, text, blocks) when is_binary(blocks) do
    do_post_message(token, channel, [text: text, blocks: blocks])
  end

  def post_message(token, channel, text, blocks) when is_list(blocks) do
    do_post_message(token, channel, [text: text, blocks: Jason.encode!(blocks)])
  end

  def conversation_history(token, channel, limit) do
    {_status, %HTTPoison.Response{body: body}} = HTTPoison.post(
      "https://slack.com/api/conversations.history",
      {:form,
      [
      token: token,
      channel: channel,
      limit: limit
      ]
      })
    response = Jason.decode!(body, keys: :atoms)
    case response.ok do
      true -> {:ok, response}
      _ -> {:error, response.error}
    end
  end

  @spec do_post_message(binary(), binary(), Keyword.t()) :: {:ok, any()} | {:error, any()}
  defp do_post_message(token, channel, form_data) do
    {_status, %HTTPoison.Response{body: body}} = HTTPoison.post(
      "https://slack.com/api/chat.postMessage",
      {:form,
      [
      token: token,
      channel: channel
      ]
      |> Keyword.merge(form_data, fn _k, v1, _v2 -> v1 end)
      })
    response = Jason.decode!(body, keys: :atoms)
    case response.ok do
      true -> {:ok, response.channel}
      _ -> {:error, response.error}
    end
  end
end
