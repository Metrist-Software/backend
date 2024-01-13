defmodule Backend.Integrations.Teams do
  require Logger

  @scope [
    "openid",
    "profile",
    "email",
    "User.Read"
  ]
  |> Enum.join(" ")

  @doc """
  Return the OAuth2 URL to get authorized with Teams. Token is a signed token that the
  caller can verify for authenticity on return.
  """
  def oauth_url(token, redirect_to) do
    settings = Application.get_env(:backend, :teams)
    query = [
      client_id: settings.auth_client_id,
      response_type: "code",
      scope: @scope,
      state: token,
      prompt: "consent",
      redirect_uri: redirect_to
    ]
    |> URI.encode_query()

    "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize?#{query}"
  end

  @doc """
  Convert the code returned into {tenant id,tenant name}, which is all we want.
  """
  def tenant_info_from_oauth_code(code, redirect_to) do
    settings = Application.get_env(:backend, :teams)

    # Part one - use the code granted to retrieve the id token
    payload = {:form, [
      client_id: settings.auth_client_id,
      scope: @scope,
      code: code,
      grant_type: "authorization_code",
      client_secret: settings.auth_client_secret,
      redirect_uri: redirect_to
    ]}
    {:ok, %HTTPoison.Response{body: body_json}} =
      HTTPoison.post("https://login.microsoftonline.com/organizations/oauth2/v2.0/token",
        payload)
    case Jason.decode!(body_json) do
     %{"error" => _error, "error_description" => error_description } ->
      Logger.info("Oauth2 call failed, reason: #{error_description}")
      {:error, {:error, "Oauth2 call failed. Please try again." }}

     %{"access_token" => access_token, "id_token" => id_token} ->
      # Part two - do JWT magics to get the tenant id. Not going to do the OpenID
      # verification dance, we just got the token from MS so it should be good.
      tenant_id = get_tenant_id_from_id_token(id_token)

      # Part three - get the tenant name from access token
      tenant_name = get_tenant_name_from_access_token(access_token)

      {:ok, tenant_id, tenant_name}
    end
  end

  def attach_workspace_to_account(account_id, tenant_uuid, tenant_name) do
    case Backend.Projections.get_microsoft_tenant(tenant_uuid) do
      nil ->
        cmd = %Domain.Account.Commands.AttachMicrosoftTenant{
          id: account_id,
          tenant_id: tenant_uuid,
          name: tenant_name
        }
        {:ok, cmd}
      existing ->
        msg = if existing.account_id == account_id do
            {:info, "This Teams workspace was already attached to your account"}
          else
            {:error, "Another account already has this Teams workspace attached"}
          end
        Logger.info("Not attaching teams workspace, user message: #{inspect msg}, existing account id #{existing.account_id}")
        {:error, msg}
    end
  end

  defp get_tenant_id_from_id_token(id_token) do
    id_token
    |> String.split(".")                             # JWT is three parts
    |> Enum.at(1)                                    # 0=hdr, 1=payload, 2=sig
    |> Base.url_decode64!(padding: false)            # encoded in base64
    |> Jason.decode!()                               # and there's the paydirt in JSON
    |> Map.get("tid")
  end

  defp get_tenant_name_from_access_token(access_token) do
    headers = ["Authorization": "Bearer #{access_token}", "Accept": "Application/json; Charset=utf-8"]
    {:ok, %HTTPoison.Response{body: body_json}} =
      HTTPoison.get("https://graph.microsoft.com/v1.0/organization",
      headers)
    body = Jason.decode!(body_json)

    tenant_name = body
    |> Map.get("value")
    |> Enum.at(0)
    |> Map.get("displayName")
    Logger.info("Tenant name is: #{tenant_name}")
    tenant_name
  end
end
