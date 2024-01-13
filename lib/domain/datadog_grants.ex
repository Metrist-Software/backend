defmodule Domain.DatadogGrants do
  @derive Jason.Encoder
  defstruct [
    :id,
    :user_id
  ]

  alias __MODULE__.Commands
  alias __MODULE__.Events

  def execute(%__MODULE__{}, c = %Commands.RequestGrant{}) do
    %Events.GrantRequested{id: c.id, user_id: c.user_id, verifier: c.verifier}
  end

  def execute(
        self = %__MODULE__{},
        c = %Commands.UpdateGrant{}
      ) do
    %Events.GrantUpdated{
      id: self.id,
      access_token: c.access_token,
      refresh_token: c.refresh_token,
      scope: c.scope,
      expires_in: c.expires_in
    }
  end

  def apply(self = %__MODULE__{}, e = %Events.GrantRequested{}) do
    %__MODULE__{
      self
      | id: e.id,
        user_id: e.user_id
    }
  end

  def apply(
        self = %__MODULE__{},
        %Events.GrantUpdated{}
      ) do
    self
  end
end
