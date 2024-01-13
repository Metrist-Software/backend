defmodule Mix.Tasks.Metrist.OneOff.RemoveOrphanedSlackWorkspaces do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-485 Find and remove orphaned slack workspaces"

  def run(args) do
    {opts, []} = Helpers.do_parse_args(
      args,
      [
        env: :string,
        dry_run: :boolean
      ],
      [
        e: :env,
        d: :dry_run
      ],
      [
        :env
      ]
    )


    opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Task.run("app.config")

    # Mix.Tasks.Metrist.Helpers.start_repos()
    Logger.configure(level: :info)

    Application.ensure_all_started(:hackney)

    import Ecto.Query, warn: false
    alias Backend.Repo

    all_workspaces = Backend.Projections.SlackWorkspace
    |> Repo.all()

    workspace_results = for workspace <- all_workspaces do
      Logger.info("Checking #{workspace.id} on account #{workspace.account_id}")
      case HTTPoison.get!(
            "https://slack.com/api/conversations.list?limit=1",
            [{"content-type", "application/x-www-form-urlencoded"}, {"authorization", "Bearer #{workspace.access_token}"}]
          ) do
            %{status_code: 200, body: body} ->
              decoded = Jason.decode!(body)
              case decoded["ok"] do
                true ->
                  nil
                false ->
                  Logger.info("\t\tFailed with #{decoded["error"]}")
                  {workspace.account_id, workspace, decoded["error"]}
              end
          end
    end
    |> Enum.reject(fn item -> item == nil end)

    remove_workspace_commands =
      workspace_results
      |> Enum.map(fn {account_id, workspace, _error} ->
        %Domain.Account.Commands.RemoveSlackWorkspace{
          id: account_id,
          team_id: workspace.id
        }
      end)

    case opts[:dry_run] do
      true ->
        accounts = Backend.Projections.list_accounts()
        for {account_id, workspace, error} <- workspace_results do
          account_name = Enum.find(accounts, fn account -> account.id == account_id end).name
          Logger.info("Would remove slack workspace #{workspace.id} from account #{account_id}:#{account_name} because of: #{error}")
        end
        remove_workspace_commands
        |> IO.inspect(label: "Commands")
        Logger.info("#{length(remove_workspace_commands)} commands would be sent")
      _ ->
        Logger.info("Sending #{length(remove_workspace_commands)} commands")
        Mix.Tasks.Metrist.Helpers.send_commands(remove_workspace_commands, opts[:env])
        Logger.info("Done sending #{length(remove_workspace_commands)} commands")
    end
  end
end
