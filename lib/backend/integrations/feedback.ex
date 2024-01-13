defmodule Backend.Integrations.Feedback do
  @moduledoc """
  Client for posting feedback forms, currently to
  Atlassian Jira
  """

  require Logger

  def submit_feedback(user, ua, path, feedback) do
    url = "https://metrist.atlassian.net/rest/api/2/issue/"
    body = make_issue(user, ua, path, feedback)
    headers = [
      {"content-type", "application/json"},
      {"authorization", make_auth_header()}
    ]

    case HTTPoison.post!(url, body, headers) do
      %{status_code: 200} ->
        :ok
      %{status_code: 201} ->
        :ok
      %{status_code: other} = response ->
        Logger.error("Feedback: ERROR Unexpected result #{other} submitting feedback. Logging feedback info.")
        Logger.info("Feedback: Response: #{inspect response}")
        Logger.info("Feedback: User: #{inspect user}")
        Logger.info("Feedback: User Agent: #{inspect ua}")
        Logger.info("Feedback: Path: #{path}")
        Logger.info("Feedback: Comments: #{feedback}")
    end
  end

  defp make_issue(user, ua, path, feedback) do
    account_name = user.account_id
    |> Backend.Projections.get_account()
    |> Backend.Projections.Account.get_account_name()

    %{
      fields: %{
        project: %{
          key: "CF" # Jira "Customer Feedback" project
        },
        issuetype: %{
          name: "Task"
        },
        summary: "Feedback by #{user.email}",
        description: """
        UserId: #{user.id}
        Email: #{user.email}
        HubspotId: #{user.hubspot_contact_id}
        AccountId: #{user.account_id}
        AccountName: #{account_name}
        Path: #{path}
        UserAgent: #{ua}

        Feedback:
        #{feedback}
        """
      }
    }
    |> Jason.encode!()
  end

  defp make_auth_header do
    auth_data = Application.get_env(:backend, :feedback_key)
    auth_64 = Base.encode64("#{auth_data["username"]}:#{auth_data["password"]}")
    "Basic #{auth_64}"
  end
end
