defmodule Domain.SlackIntegration.Events do
  use TypedStruct

  typedstruct module: ConnectionRequested, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :account_id, String.t
    field :redirect_to, String.t, enforce: false
  end

  typedstruct module: ConnectionCompleted, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :account_id, String.t
    field :code, String.t
    field :redirect_to, String.t, enforce: false
  end

  typedstruct module: ConnectionFailed, enforce: true do
    @derive Jason.Encoder
    field :id, String.t
    field :reason, String.t
    field :existing_account_id, String.t, enforce: false
  end
end
