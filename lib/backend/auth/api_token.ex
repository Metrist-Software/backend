defmodule Backend.Auth.APIToken do
  @moduledoc """
  Functions for dealing with user-held API tokens.
  """

  @key_bytes 32

  @doc """
  Generate a new API token.
  """
  def generate(account_id, actor) do
    token = make_token()
    cmd = %Domain.Account.Commands.AddAPIToken{
      id: account_id,
      api_token: token
    }
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(actor, cmd)
    token
  end

  @doc """
  Removes an existing API token and generates a new one
  """
  def rotate(account_id, actor, existing_api_token) do
    token = make_token()

    cmd = %Domain.Account.Commands.RotateAPIToken{
      id: account_id,
      existing_api_token: existing_api_token,
      new_api_token: token
    }
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(actor, cmd)
    token
  end

  @doc """
  Verify an API token. Returns the account id found or nil
  """
  def verify(api_token) do
    case Backend.Projections.get_api_token(api_token) do
      nil -> nil
      entry -> entry.account_id
    end
  end

  @doc """
  Return all API keys for the account
  """
  def list(account_id), do: Backend.Projections.list_api_tokens(account_id)

  defp make_token() do
    @key_bytes
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
    |> Integer.to_string(36)
  end
end
