defmodule Mix.Tasks.Metrist.CreateSlackTestApp do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @opts [
    :dry_run,
  ]
  @shortdoc "Create slack test app (Only to be used if you don't have a test slack app already. apps.manifest beta API's do not have a way to check or list exising apps)"
  @moduledoc """
  #{@shortdoc}

  WARNING: Slack will happily create multiple version of the same app with the same app name and there is no API to list apps.

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do

    [:hackney, :jason]
    |> Enum.map(&Application.ensure_all_started/1)

    options = Helpers.parse_args(@opts, args)

    config_token = System.get_env("SLACK_APP_CONFIGURATION_TOKEN")
    identifier = System.get_env("SLACK_TEST_APP_IDENTIFIER")

    if !config_token or !identifier do
      Logger.error("""
      SLACK_APP_CONFIGURATION_TOKEN, SLACK_TEST_APP_IDENTIFIER, and SLACK_TEST_APP_ID must be set.
      SLACK_APP_CONFIGURATION_TOKEN If you do not have a configuration token generate one at https://api.slack.com/apps. They only last for 12 hours and can't be created programatically.
      SLACK_TEST_APP_IDENTIFIER must be a set to a unique suffix for your test app such as "dave"
      """)
      exit(:required_environment_variables_missing)
    end

    updated_manifest =
      File.read!("slack-dev-manifest-template.json")
      |> String.replace("<identifier>", identifier)

    case options.dry_run do
      true ->
        Logger.info("DRY-RUN: Would send the following manifest to apps.manifest.create")
        Logger.info(updated_manifest)
      false ->
        {:ok, %HTTPoison.Response{body: body}} = HTTPoison.post(
          "https://slack.com/api/apps.manifest.create",
          {:form, [
              token: config_token,
              manifest: updated_manifest
            ]})
        Logger.info(body)
        info = Jason.decode!(body, keys: :atoms)
        result = case info.ok do
          true ->
            Logger.info("""
              Your test slack app has been created. Only run this once. Please set SLACK_TEST_APP_ID env var to #{info.app_id} and your SLACK_SIGNING_SECRET to #{info.credentials.signing_secret} before running make slack_test
            """)
          _ -> {:error, info.error}
        end
        Logger.info("#{inspect result}")
    end
  end
end
