defmodule Domain.DatadogGrants.Events do
  use TypedStruct

  typedstruct module: GrantRequested, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :user_id, String.t()
    field :verifier, String.t()
  end

  typedstruct module: GrantUpdated, enforce: true do
    @derive Jason.Encoder
    field :id,            String.t()
    field :access_token,  String.t()
    field :refresh_token, String.t()
    field :scope,         [String.t()]
    field :expires_in,    integer()
  end
end
