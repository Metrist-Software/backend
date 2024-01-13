defmodule Domain.SlackIntegration do
  defmodule AuthState do
    # if non-nil, an authorization is in progress.
    # TODO timeout. Community wisdom is to pull in the Oban package to send
    # a delayed "cancel" command.
    defstruct [:uri]
  end

  @derive Jason.Encoder
  defstruct [:id, :account_id, :auth_state]

  alias __MODULE__.Commands
  alias __MODULE__.Events

  def execute(%__MODULE__{id: nil}, c = %Commands.RequestConnection{}) do
    %Events.ConnectionRequested{id: c.id,
                                account_id: c.account_id,
                                redirect_to: c.redirect_to}
  end

  def execute(self = %__MODULE__{}, c = %Commands.CompleteConnection{}) do
    %Events.ConnectionCompleted{id: self.id,
                                account_id: self.account_id,
                                code: c.code,
                                redirect_to: self.auth_state.uri}
  end

  def execute(self = %__MODULE__{}, c = %Commands.FailConnection{}) do
    %Events.ConnectionFailed{id: self.id,
                             reason: c.reason,
                             existing_account_id: c.existing_account_id}
  end

  def apply(self, e = %Events.ConnectionRequested{}) do
    auth_state = %AuthState{uri: e.redirect_to}
    %__MODULE__{self |
                id: e.id,
                account_id: e.account_id,
                auth_state: auth_state}
  end

  # We can maybe use auth_state being nil to guard against duplicate invocations.
  def apply(self, %Events.ConnectionCompleted{}) do
    %__MODULE__{self | auth_state: nil}
  end

  def apply(self, %Events.ConnectionFailed{}) do
    %__MODULE__{self | auth_state: nil}
  end
end
