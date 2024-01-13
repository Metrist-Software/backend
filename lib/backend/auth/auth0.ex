defmodule Backend.Auth.Auth0 do
  require Logger

  def init() do
    # We stuff the management token in an ETS table with expiry so we don't
    # need to fetch it over and over again.
    :ets.new(__MODULE__, [:set, :public, :named_table, read_concurrency: true])
  end

  defp get_management_token() do
    case get_token_from_ets() do
      nil -> get_new_token()
      token -> token
    end
  end

  defp get_token_from_ets() do
    case :ets.lookup(__MODULE__, :token) do
      [{:token, expiry, token}] ->
        expires_in = expiry - :erlang.system_time(:second)
        if expires_in < 0 do
          nil
        else
          Logger.debug("Reuse token from cache, expires in #{expires_in} seconds")
          token
        end
      _ ->
        nil
    end
  end

  defp get_new_token() do
    secrets = Application.get_env(:backend, :auth0_m2m_secrets)

    payload =
      {:form,
       [
         grant_type: "client_credentials",
         client_id: secrets.m2m_client_id,
         client_secret: secrets.m2m_client_secret,
         audience: secrets.m2m_audience
       ]}

    {:ok, %HTTPoison.Response{body: body_json}} =
      HTTPoison.post("https://#{secrets.host}/oauth/token", payload)

    body = Jason.decode!(body_json)

    # We refresh before expiry so we never risk using an expired token.
    expires_in = body["expires_in"] * 0.9
    expiry = :erlang.system_time(:second) + expires_in
    token = {body["access_token"], secrets.host, secrets.m2m_client_id}

    :ets.insert(__MODULE__, {:token, expiry, token})
    Logger.debug("Refreshed auth0 token, expires in #{expires_in} seconds")
    token
  end

  def resend_verification_mail(uid) do
    {token, host, client_id} = get_management_token()

    body = %{
      user_id: uid,
      client_id: client_id
    }

    {:ok, %HTTPoison.Response{status_code: 201}} =
      HTTPoison.post(
        "https://#{host}/api/v2/jobs/verification-email",
        Jason.encode!(body),
        [{"content-type", "application/json"},
         {"authorization", "Bearer #{token}"}])
    Logger.debug("Resent verification mail for uid #{uid}")
  end

  def is_verified(uid) do
    {token, host, _id} = get_management_token()

    {:ok, %HTTPoison.Response{status_code: 200, body: body_json}} =
      HTTPoison.get(
        "https://#{host}/api/v2/users/#{uid}",
        [{"authorization", "Bearer #{token}"}])
    body = Jason.decode!(body_json)

    # If "email_verified" isn't on the response, then the user signed in through OAuth instead of email/password
    # In this case, default to true and consider them verified
    verified = Map.get(body, "email_verified", true)
    Logger.debug("Checked verification status for uid #{uid}: #{verified}")
    verified
  end

  def try_delete_user(uid) do
     {token, host, _id} = get_management_token()

     case HTTPoison.delete(
      "https://#{host}/api/v2/users/#{uid}",
      [{"authorization", "Bearer #{token}"}]) do
        {:ok, %HTTPoison.Response{status_code: 204}} ->
          Logger.info("Deleted Auth0 user for uid #{uid}")
        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          Logger.info("Invalid response from auth0 on delete. Status Code: #{status_code} UID:#{uid}")
        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.info("Could not delete user from Auth0. Reason: #{reason}. UID:#{uid}")
      end
  end

  def logout_url(return_to) do
    {_, host, _} = get_management_token()
    client_id = Application.get_env(:backend, :auth0_client_id)
    "https://#{host}/v2/logout?#{URI.encode_query(returnTo: return_to, client_id: client_id)}"
  end

end
