defmodule Mix.Tasks.Metrist.OneOff.TagMonitors do
  use Mix.Task

  @shortdoc "Apply default tags to monitors"

  @tags %{
    azure: [
      "azuread",
      "azureaks",
      "azureblob",
      "azurecdn",
      "azuredb",
      "azuredevops",
      "azurefncs",
      "azuresql",
      "azurevm"
    ],
    aws: [
      "awsecs",
      "awsiam",
      "awslambda",
      "awsrds",
      "ec2",
      "kinesis",
      "s3",
      "sqs",
      "ses",
      "cognito"
    ],
    api: [
      "avalara",
      "bambora",
      "braintree",
      "easypost",
      "fastly",
      "gcal",
      "github",
      "gmaps",
      "hubspot",
      "moneris",
      "pubnub",
      "sendgrid",
      "stripe"
    ],
    infrastructure: [
      "cloudflare",
      "gke",
      "heroku",
      "ravendb"
    ],
    saas: [
      "authzero",
      "circleci",
      "datadog",
      "jira",
      "npm",
      "nuget",
      "pagerduty",
      "sentry",
      "slack",
      "trello",
      "zendesk",
      "zoom"
    ]
  }

  @removes %{
    infrastructure: [
      "awsecs",
      "awsiam",
      "awslambda",
      "awsrds",
      "azuread",
      "azureaks",
      "azureblob",
      "azurecdn",
      "azuredb",
      "azuredevops",
      "azurefncs",
      "azuresql",
      "azurevm",
      "ec2",
      "kinesis",
      "s3",
      "sqs",
      "ses",
      "cognito"
    ],
    api: [
      "ses"
    ]
  }

  @dialyzer {:no_return, run: 1}
  def run(args) do
    Mix.Task.run("app.config")

    env = Mix.Tasks.Metrist.Helpers.env_from_opts(args)
    config = Mix.Tasks.Metrist.Helpers.config_from_env(env)

    #%{"token" => token} =
      Backend.Application.get_json_secret(
        "canary-internal/api-token",
        config.secrets_namespace,
        config.region
      )

    for {tag, _monitors} <- @tags do
      IO.puts("Adding tag #{tag}")

      #for logical_name <- monitors do
        #Mix.Tasks.Metrist.Helpers.send_command(config, token, %Domain.Monitor.Commands.AddTag{
          #id: Backend.CommandTranslator.translate_id("SHARED", logical_name),
          #tag: tag
        #})
      #end
    end

    for {tag, _monitors} <- @removes do
      IO.puts("Removing double tags for #{tag}")

      #for logical_name <- monitors do
        #Mix.Tasks.Metrist.Helpers.send_command(config, token, %Domain.Monitor.Commands.RemoveTag{
          #id: Backend.CommandTranslator.translate_id("SHARED", logical_name),
          #tag: tag
        #})
      #end
    end
  end
end
