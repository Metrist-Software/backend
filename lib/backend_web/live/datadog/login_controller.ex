defmodule BackendWeb.Datadog.LoginController do
  use BackendWeb, :controller
  require Logger

  plug :access_grant

  action_fallback BackendWeb.FallbackController

  @auth_complete_path "/dd-metrist/auth/complete?auto-close=true"

  # Auth check for UI Widgets. Datadog will call this once when the widget first loads to see if the
  # user is authenticated. We consider any user that is logged into Metrist
  def auth_check(conn, _params) do
    json(conn, "ok")
  end

  def auth_app(conn, _params) do
    user =
      conn
      |> get_session(:current_user)

    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(user, %Domain.User.Commands.DatadogLogin{id: user.id})

    # Just go straight to the complete path/messaging. This is from the Widgets where we don't
    # care about the confidential oauth client
    redirect(conn, to: @auth_complete_path)
  end

  def auth_request(conn, params) do
    access_grant = conn.assigns.access_grant

    conn
    |> maybe_refresh_grants(access_grant)
    |> redirect_continue(params, access_grant)
  end

  # If the grant is expired (utcnow > grant.expires_at) refresh the token
  # Datadog does not have a tokeninfo endpoint which we would be able to use with a simple get request
  # to validate that the access token is not revoked. Instead, if we have an expired token we will try
  # to refresh it which will fail if the tokens have been revoked for any reason.
  defp maybe_refresh_grants(conn, access_grant) when access_grant.refresh_token != nil do
    if grant_expired?(access_grant.expires_at) do
      with {:ok, body} <- Backend.Integrations.Datadog.refresh(access_grant.refresh_token) do
        connection_completed(access_grant, body)
        Logger.info("Successfully renewed grants for grant id: #{access_grant.id}")
        {:halt, redirect(conn, to: @auth_complete_path)}
      else
        error ->
          Logger.warn("Failed to refresh grants with reason #{inspect(error)}. Continuing")
          {:continue, conn}
      end
    else
      Logger.info("Grant #{access_grant.id} is still up to date. Halting")
      {:halt, redirect(conn, to: @auth_complete_path)}
    end
  end

  defp maybe_refresh_grants(conn, _access_grant), do: {:continue, conn}

  # Request authorization for a user if an access token does not exist
  # This follows the OAuth protocol highlighted here
  # https://docs.datadoghq.com/developers/authorization/oauth2_in_datadog/#implement-the-oauth-protocol
  defp redirect_continue({:continue, conn}, _params, access_grant) do
    verifier = Ecto.UUID.generate()

    id =
      case access_grant do
        %{id: id} -> id
        nil -> Domain.Id.new()
      end

    %Domain.DatadogGrants.Commands.RequestGrant{
      id: id,
      user_id: user_id(conn),
      verifier: verifier
    }
    |> Backend.App.dispatch()

    conn
    |> redirect(external: Backend.Integrations.Datadog.authorization_url(verifier))
  end

  defp redirect_continue({_any, conn}, _params, _access_grant), do: conn

  def auth_callback(conn, %{"code" => code} = params) do
    access_grant = conn.assigns.access_grant
    # The followup API call needs to use the `site` query param as stated here
    # https://docs.datadoghq.com/developers/authorization/oauth2_in_datadog/#initiate-authorization-from-a-third-party-location
    site = params["site"]

    with {:ok, body} <-
           Backend.Integrations.Datadog.request_token(access_grant.verifier, code, site) do
      connection_completed(access_grant, body)
      redirect(conn, to: @auth_complete_path)
    end
  end

  defp user_id(conn), do: get_session(conn, :current_user).id

  defp access_grant(conn, _options) do
    access_grant =
      conn
      |> user_id()
      |> Backend.Datadog.AccessGrants.get_by_user_id()

    assign(conn, :access_grant, access_grant)
  end

  defp connection_completed(access_grant, body) do
    %Domain.DatadogGrants.Commands.UpdateGrant{
      id: access_grant.id,
      verifier: access_grant.verifier,
      access_token: body["access_token"],
      refresh_token: body["refresh_token"],
      scope: String.split(body["scope"]),
      expires_in: body["expires_in"]
    }
    |> Backend.App.dispatch()
  end

  defp grant_expired?(expires_at) when expires_at != nil do
    result =
      DateTime.utc_now()
      |> DateTime.compare(expires_at)

    result == :gt
  end

  # If expires_at is nil, treat it as an expired grant
  defp grant_expired?(_), do: true
end
