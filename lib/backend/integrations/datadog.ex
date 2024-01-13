defmodule Backend.Integrations.Datadog do
  require Logger

  def authorization_url(verifier) do
    query = Backend.Integrations.Datadog.authorize_query(verifier, dd_config())

    "https://app.datadoghq.com/oauth2/v1/authorize?#{query}"
  end

  def authorize_query(verifier, config) do
    redirect_uri = Keyword.fetch!(config, :redirect_uri)
    client_id = Keyword.fetch!(config, :client_id)

    %{
      "redirect_uri" => redirect_uri,
      "client_id" => client_id,
      "response_type" => "code",
      "code_challenge" => :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false),
      "code_challenge_method" => "S256"
    }
    |> URI.encode_query()
  end

  def authorize_url(query), do: "https://app.datadoghq.com/oauth2/v1/authorize?#{query}"

  def request_token(verifier, code, site) do
    post_body = Backend.Integrations.Datadog.token_query(verifier, code, dd_config())

    Backend.Integrations.Datadog.oauth_v1_post(post_body, site: site)
  end

  def token_query(verifier, code, config) do
    redirect_uri = Keyword.fetch!(config, :redirect_uri)
    client_id = Keyword.fetch!(config, :client_id)
    client_secret = Keyword.fetch!(config, :client_secret)

    %{
      "redirect_uri" => redirect_uri,
      "client_id" => client_id,
      "client_secret" => client_secret,
      "grant_type" => "authorization_code",
      "code_verifier" => verifier,
      "code" => code
    }
    |> URI.encode_query()
  end

  def refresh(refresh_token) do
    post_body =
      Backend.Integrations.Datadog.refresh_token_query(
        refresh_token,
        dd_config()
      )

    Backend.Integrations.Datadog.oauth_v1_post(post_body)
  end

  def refresh_token_query(refresh_token, config) do
    redirect_uri = Keyword.fetch!(config, :redirect_uri)
    client_id = Keyword.fetch!(config, :client_id)
    client_secret = Keyword.fetch!(config, :client_secret)

    %{
      "redirect_uri" => redirect_uri,
      "client_id" => client_id,
      "client_secret" => client_secret,
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token
    }
    |> URI.encode_query()
  end

  def oauth_v1_post(body, opts \\ []) do
    site = Keyword.get(opts, :site, "https://app.datadoghq.com")

    with {:ok, %{body: response_body}} <-
           HTTPoison.post(
             "#{site}/oauth2/v1/token",
             body,
             %{"Content-Type" => "application/x-www-form-urlencoded"}
           )
           |> handle_response do
      Jason.decode(response_body)
    end
  end

  defp handle_response({:ok, %{status_code: 200}} = result), do: result

  defp handle_response({:ok, reason}) do
    Logger.error("Datadog did not repond ok 200 status. Reason: #{inspect(reason)}")
    {:error, :non_200_response}
  end

  defp handle_response(response), do: response

  defp dd_config do
    Application.fetch_env!(:backend, :dd_oauth2_client)
  end
end
