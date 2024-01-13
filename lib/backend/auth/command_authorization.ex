defmodule Backend.Auth.CommandAuthorization do

  alias Domain.User.Commands, as: UserCmds
  require Logger

  # TODO: Investigate Commanded Middleware for authenticating
  #       dispatches https://hexdocs.pm/commanded/Commanded.Middleware.html
  def dispatch_with_auth_check(actor, command, opts \\ [])

  # USER auth check
  def dispatch_with_auth_check(%Phoenix.LiveView.Socket{ assigns: %{ current_user: current_user } }, command, opts) do
    dispatch_with_auth_check(current_user, command, opts)
  end
  def dispatch_with_auth_check(user=%Backend.Projections.User{}, command, opts) do
    case can?(user, :command, command) do
      true ->
        BackendWeb.Helpers.dispatch_with_meta(user, command, opts)
      _ ->
        Logger.info("Blocked user id #{user.id} from using command #{inspect command, pretty: true}. User: #{inspect user, pretty: true}")
        {:error, :read_only_user}
    end
  end

  # If no specific user, let it pass through
  def dispatch_with_auth_check(conn, command, opts) do
    BackendWeb.Helpers.dispatch_with_meta(conn, command, opts)
  end

  # current_user that is nil can't issue any commands
  def can?(nil, :command, _command), do: false
  def can?(%{ is_metrist_admin: true }, :command, _command), do: true
  def can?(%{ is_read_only: true }, :command, %UserCmds.UpdateTimezone{}), do: true
  def can?(%{ is_read_only: true }, :command, %UserCmds.Login{}), do: true
  def can?(%{ is_read_only: true }, :command, %UserCmds.Logout{}), do: true
  def can?(%{ is_read_only: true }, :command, %UserCmds.Print{}), do: true
  def can?(%{ is_read_only: true }, :command, %Domain.Notice.Commands.MarkRead{}), do: true
  def can?(%{ is_read_only: true }, :command, %Domain.User.Commands.UpdateAuth0Info{}), do: true
  def can?(%{ is_read_only: true }, :command, %Domain.User.Commands.Update{}), do: true
  def can?(%{ is_read_only: true }, :command, %Domain.User.Commands.UpdateSlackDetails{}), do: true
  def can?(%{ is_read_only: true }, :command, %Domain.User.Commands.AcceptInvite{}), do: true
  def can?(%{ is_read_only: true }, :command, _command), do: false
  def can?(%{ is_read_only: false}, :command, _command), do: true
end
