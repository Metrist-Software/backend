defmodule Mix.Tasks.Metrist.InstallMonitorTest do
  use ExUnit.Case, async: true

  import Mix.Tasks.Metrist.InstallMonitor

  test "Valid file validates" do
    json = """
    {
      "name": "awscloudwatch",
      "description": "AWS Cloudwatch",
      "tag": "aws",
      "run_spec": {
        "type": "exe"
      },
      "steps": [
        {
          "name": "SubmitEvent",
          "description": "Submit a metric to Cloudwatch using the PutMetricData API call"
        },
        {
          "name": "GetEvent",
          "description": "List metrics matching our test metric we submitted using the ListMetricsCommand API call"
        }
      ],
      "extra_config": {
        "AWSAccessKeyID": "@secret@:@env@:$${SECRETS_NAMESPACE}monitors/awscloudwatch/secrets#aws_access_key_id",
        "AWSSecretAccessKey": "@secret@:@env@:$${SECRETS_NAMESPACE}monitors/awscloudwatch/secrets#aws_secret_access_key"
      }
    }
    """

    validate_monitor(json)
  end

  test "Bad file raises" do
    json = """
    {
      "name": "awscloudwatch",
      "description": "AWS Cloudwatch",
      "tag": "aws",
      "run_spec": {
        "type": "exe",
        "name": "awscloudwatch_monitor_executable"
      },
      "steps": [
        {
          "description": "Submit a metric to Cloudwatch using the PutMetricData API call"
        },
        {
          "name": "GetEvent",
          "description": "List metrics matching our test metric we submitted using the ListMetricsCommand API call"
        }
      ],
      "extra_config": {
      }
    }
    """

    assert_raise MatchError, fn -> validate_monitor(json) end
  end
end
