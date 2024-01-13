defmodule Domain.Processes.SlackIntegration do
  use Commanded.ProcessManagers.ProcessManager,
    application: Backend.App,
    name: __MODULE__,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  # NOTE: all commands emitted here must have idempotency checks in the
  # aggregate root!

  require Logger

  # For now, no state but the framework needs this regardless
  @derive Jason.Encoder
  defstruct []

  alias Domain.SlackIntegration.Events.ConnectionRequested
  alias Domain.SlackIntegration.Events.ConnectionCompleted
  alias Domain.Account.Events.SlackWorkspaceAttached
  alias Domain.Account.Commands.AttachSlackWorkspace
  alias Domain.SlackIntegration.Commands.FailConnection

  @impl true
  def interested?(%ConnectionRequested{id: id}), do: {:start, id}
  @impl true
  def interested?(%ConnectionCompleted{id: id}), do: {:continue, id}
  @impl true
  def interested?(%SlackWorkspaceAttached{integration_id: id}), do: {:stop, id}

  @impl true
  def handle(_state, %ConnectionRequested{}) do
    # Absolutely nothing. But we could (should) start a timeout here using Oban.
  end

  @impl true
  def handle(_state, e = %ConnectionCompleted{}) do
    # Use the code to obtain the data and then attach slack.
    # NOTE: we now call from "Domain" back into "Backend" - code smell or should
    # we just move the slack code? My hunch is the latter.
    app_access = Backend.Integrations.Slack.get_app_access_token(e.code, e.redirect_to)

    case app_access.ok do
      false ->
        Logger.error("Got error from Slack: #{app_access.error}")
        %FailConnection{
          id: e.id,
          reason: app_access.error
        }

      true ->
        attach_cmd = %AttachSlackWorkspace{
          id: e.account_id,
          integration_id: e.id,
          team_id: app_access.team.id,
          team_name: app_access.team.name,
          scope: String.split(app_access.scope, ","),
          bot_user_id: app_access.bot_user_id,
          access_token: app_access.access_token
        }
        # TODO: with checkpointing, this can potentially be called twice. Do we
        # want to handle this unlikely case? If so, do we want to be able to
        # differentiate between a replay and two users attaching the same WS?
        case Backend.Projections.get_slack_workspace(app_access.team.id) do
          nil ->
            %AttachSlackWorkspace{
              id: e.account_id,
              integration_id: e.id,
              team_id: app_access.team.id,
              team_name: app_access.team.name,
              scope: String.split(app_access.scope, ","),
              bot_user_id: app_access.bot_user_id,
              access_token: app_access.access_token,
              message: "Connection successful to #{app_access.team.name}"
            }
          existing ->
              if existing.account_id == e.account_id do
                attach_cmd
                |> Map.put(:message, "Already connected to #{app_access.team.name}")
              else
                Logger.info("Not attaching workspace as it's attached to another account. Existing account id #{existing.account_id}")
                %FailConnection{
                  id: e.id,
                  reason: "Another account already has this Slack workspace attached",
                  existing_account_id: existing.account_id
                }
              end
        end
    end
  end
end
