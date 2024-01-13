defmodule Domain.DatadogGrants.Commands do
  use TypedStruct

  typedstruct module: RequestGrant, enforce: true do
    use Domo
    field :id, String.t()
    field :user_id, String.t()
    field :verifier, String.t()
  end

  typedstruct module: UpdateGrant, enforce: true do
    use Domo
    field :id, String.t()
    field :verifier, String.t()
    field :access_token, String.t()
    field :refresh_token, String.t()
    field :scope, [String.t()]
    field :expires_in, integer()
  end
end
