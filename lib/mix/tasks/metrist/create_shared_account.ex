defmodule Mix.Tasks.Metrist.CreateSharedAccount do
  use Mix.Task

  @shortdoc "Creates the SHARED account if required"

  @moduledoc """
  This Mix tasks emits a command to create the shared account if it does not exist. Only works against the
  local environment currently.
  """

  alias Mix.Tasks.Metrist.Helpers

  def run(_) do
    Helpers.bootstrap_start_everything("local")

    case Backend.Projections.get_user("ADMIN") do
      nil ->
        cmd = %Domain.User.Commands.Create{
          id: "ADMIN",
          user_account_id: "SHARED",
          email: "admin@example.com"
        }
        Backend.App.dispatch(cmd, metadata: %{actor: Backend.Auth.Actor.metrist_mix()})
      user ->
        IO.puts("\ADMIN user already exist, not creating.\n\n")
        user
    end

    case Backend.Projections.get_account("SHARED") do
      nil ->
        cmd = %Domain.Account.Commands.Create{
          id: "SHARED",
          name: "SHARED",
          selected_instances: [],
          selected_monitors: [],
          creating_user_id: "ADMIN"
        }
        Backend.App.dispatch(cmd, metadata: %{actor: Backend.Auth.Actor.metrist_mix()})
        IO.puts("\nCreated SHARED account.\n\n")
      account ->
        IO.puts("\nSHARED account already exist, not creating.\n\n")
        account
    end
  end
end
