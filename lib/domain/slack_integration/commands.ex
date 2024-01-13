defmodule Domain.SlackIntegration.Commands do
  use TypedStruct

  typedstruct module: RequestConnection, enforce: true do
    use Domo
    field :id, String.t
    field :account_id, String.t
    field :redirect_to, String.t, enforce: false
  end

  typedstruct module: CompleteConnection, enforce: true do
    use Domo
    field :id, String.t
    field :code, String.t
  end

  typedstruct module: FailConnection, enforce: true do
    use Domo
    field :id, String.t
    field :reason, String.t
    field :existing_account_id, String.t, enforce: false
  end
end
