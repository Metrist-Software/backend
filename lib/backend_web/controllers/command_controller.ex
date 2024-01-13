defmodule BackendWeb.CommandController do
  use BackendWeb, :controller

  require Logger

  @moduledoc """
  Handle posting of arbitrary commands. We support translation between
  commands in the format of our old homebrew C# ES framework and what
  Commanded expects.
  """

  def post(conn, params) do
    cmd = Backend.CommandTranslator.translate(params)

    case execute_command(conn, cmd) do
      {:error, error} ->
        Logger.error("Could not process command: #{inspect(cmd)}\nreason: #{inspect(error)}")

        conn
        |> send_resp(500, ~s({"error": "#{inspect(error)}"}\n))
        |> halt()

      {:ok, result} ->
        # Depending on the aggregate, the json encode can fail and raise an error (e.g. if it has tuples)
        # Fallback to a plain inspect string if that happens
        try do
          json(conn, result)
        rescue
          _ -> json(conn, inspect(result))
        end

      :ok ->
        json(conn, %{})

    end
  end

  # Special handling for us allowing to send status page observations in by page name. Because
  # the missing `id:`, Elixir will interpret it as a map with a `__struct__` field instead of
  # as a struct, hence the "funny" matching.
  def execute_command(conn, cmd = %{__struct__: Domain.StatusPage.Commands.ProcessObservations})
      when not is_map_key(cmd, :id) do
    id =
      case Backend.Projections.status_page_by_name(cmd.page) do
        nil ->
          # Theoretically, there's a race condition here. In practice, status page updates are so far
          # apart that this is highly unlikely to happen.
          id = Domain.Id.new()
          execute_command(conn, %Domain.StatusPage.Commands.Create{id: id, page: cmd.page})
          id

        status_page ->
          status_page.id
      end

    Logger.info("Status page #{cmd.page} has id #{id}")
    execute_command(conn, Map.put(cmd, :id, id))
  end

  # If we put this in command_translator, we have more work to do. So leave it here for now.
  def execute_command(conn, cmd = %Domain.StatusPage.Commands.ProcessObservations{}) do
    observations =
      Enum.map(cmd.observations, fn observation ->
        %Domain.StatusPage.Commands.Observation{
          observation
          | changed_at: Backend.JsonUtils.maybe_time_from(observation.changed_at)
        }
      end)

    cmd = %Domain.StatusPage.Commands.ProcessObservations{cmd | observations: observations}
    do_execute_command(conn, cmd)
  end

  def execute_command(conn, cmd), do: do_execute_command(conn, cmd)

  def do_execute_command(conn, cmd) do
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(conn, cmd, include_execution_result: true)
  end
end

# Ensure we can just put an ExecutionResult back through Jason.
require Protocol
Protocol.derive(Jason.Encoder, Commanded.Commands.ExecutionResult)
