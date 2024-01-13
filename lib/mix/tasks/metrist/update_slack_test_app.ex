defmodule Mix.Tasks.Metrist.UpdateSlackTestApp do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @opts [
    :dry_run,
  ]
  @shortdoc "Update your existing slack app including ngrok details."
  @moduledoc """
  #{@shortdoc}

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do

    [:hackney, :jason]
    |> Enum.map(&Application.ensure_all_started/1)

    options = Helpers.parse_args(@opts, args)

    config_token = System.get_env("SLACK_APP_CONFIGURATION_TOKEN")
    slack_app_id = System.get_env("SLACK_TEST_APP_ID")
    identifier = System.get_env("SLACK_TEST_APP_IDENTIFIER")

    if !config_token or !slack_app_id or !identifier do
      Logger.error("""
      SLACK_APP_CONFIGURATION_TOKEN, SLACK_TEST_APP_IDENTIFIER, and SLACK_TEST_APP_ID must be set.
      SLACK_APP_CONFIGURATION_TOKEN If you do not have a configuration token generate one at https://api.slack.com/apps. They only last for 12 hours and can't be created programatically.
      SLACK_TEST_APP_IDENTIFIER must be a set to a unique suffix for your test app such as "dave"
      SLACK_TEST_APP_ID must be set to the id output from your first run of mix metrist.create_slack_test_app. Slack will happily create the same app a second time and there's no way to list existing ones so be careful
      """)
      exit(:required_environment_variables_missing)
    end

    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(
      "http://localhost:4040/api/tunnels")

    ngrok_host = Jason.decode!(body, keys: :atoms).tunnels
      |> Enum.filter(fn tunnel -> String.starts_with?(tunnel.public_url, "https://") end)
      |> List.first()
      |> Map.fetch!(:public_url)
      |> String.replace("https://", "")

    updated_manifest =
      File.read!("slack-dev-manifest-template.json")
      |> String.replace("<identifier>", identifier)
      |> String.replace("<ngrok-host>", ngrok_host)

    case options.dry_run do
      true ->
        Logger.info("DRY-RUN: Would send the following manifest to apps.manifest.update for app id #{slack_app_id}")
        Logger.info(updated_manifest)
      false ->
        {:ok, %HTTPoison.Response{body: body}} = HTTPoison.post(
          "https://slack.com/api/apps.manifest.update",
          {:form, [
              token: config_token,
              manifest: updated_manifest,
              app_id: slack_app_id
            ]})
        info = Jason.decode!(body, keys: :atoms)
        case info.ok do
          true ->
            Logger.info("Your slack app with ID #{info.app_id} has been sucessfully updated with the ngrok host of #{ngrok_host}")
          _ ->
            Logger.error("Your slack app could not be updated. #{info.error}")
        end
    end
  end
end
