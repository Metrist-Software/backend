defmodule Mix.Tasks.Metrist.OneOff.PopulateSlackTeamAndUserIdInUsers do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @shortdoc "MET-858 Move Slack info stored in users with Auth0 social uid to new fields for Slack team id and user id"

  @opts [
    :dry_run,
    :env
  ]

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    Backend.Projections.list_users()
    |> Enum.map(fn user ->
      case user.uid do
        << "oauth2|slack|", rest::binary>> ->
          rest
          |> String.split("-")
          |> List.to_tuple()
          |> Tuple.append(user.id)
        _ -> {nil, nil, user.id}
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn {slack_team_id, _slack_user_id, _user_id} ->
      not is_nil(slack_team_id)
    end)
    |> Enum.map(fn {slack_team_id, slack_user_id, user_id} ->
      %Domain.User.Commands.UpdateSlackDetails {
        id: user_id,
        last_seen_slack_team_id: slack_team_id,
        last_seen_slack_user_id: slack_user_id
      }
    end)
    |> Helpers.send_commands(options.env, options.dry_run)
  end
end
