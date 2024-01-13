defmodule Backend.Alerting.AlertSenderAws do
  @moduledoc """
  This module is responsible for actually processing and sending a dispatched alert.

  At present, this just means sending it through SNS but this will change as we move
  alerting into the backend.

  Once in backend (MET-874), this likely includes subscription lookups and dispatches to the proper
  alerting channels (currently handled by SNS/SQS/Lambda/Dotnet)
  """

  require Logger

  @spec send_alert(binary(), Domain.Account.Commands.Alert.t()) :: any()
  def send_alert(account_id, alert) do
    topic_arn = get_sns_topic_arn()
    publish_to_sns(account_id, alert, topic_arn)
  end

  # Converts a map to it's equivalent with PascalCase keys. Will also turn structs
  # into plain maps.
  # For the most part we want to recurse on any inner map, though we need to keep
  # NaiveDateTime structs as-is in order to be json encoded correctly
  @doc false
  def to_pascal_case(value = %NaiveDateTime{}), do: value

  def to_pascal_case(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> to_pascal_case()
  end

  @doc false
  def to_pascal_case(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} ->
      new_key =
        cond do
          is_atom(k) -> Atom.to_string(k)
          true -> k
        end
        |> Macro.camelize()

      {new_key, to_pascal_case(v)}
    end)
    |> Map.new()
  end

  @doc false
  def to_pascal_case(value) when is_list(value) do
    Enum.map(value, &to_pascal_case/1)
  end

  @doc false
  def to_pascal_case(value), do: value

  @doc false
  defp get_sns_topic_arn() do
    config = Application.get_env(:backend, Backend.RealTimeAnalytics)
    Keyword.get(config, :alerting_topic_arn)
  end

  @spec publish_to_sns(binary(), Domain.Account.Commands.Alert.t(), binary() | nil) :: any()
  defp publish_to_sns(account_id, alert, nil) do
    Logger.info("Alert Sender: Tried to publish alert #{alert.alert_id} to SNS, but Topic ARN is nil. Account ID: #{account_id} PID: #{inspect(self())}")
    Logger.info("Alert Sender: Alert was #{inspect alert, pretty: true, limit: :infinity} Account ID: #{account_id} PID: #{inspect(self())}")
  end

  defp publish_to_sns(account_id, alert, topic_arn) do
    alert
    |> transform_for_sns(account_id)
    |> Jason.encode()
    |> case do
      {:ok, json} ->
        ExAws.SNS.publish(json, topic_arn: topic_arn)
        |> Backend.Application.do_aws_request()

      {:error, err} ->
        Logger.error(err)
        err
    end
  end

  @spec transform_for_sns(Domain.Account.Commands.Alert.t(), binary()) :: any()
  defp transform_for_sns(alert, account_id) do
    # For SNS/SQS alerting compatability, we need to change these keys to match the dotnet Alert type
    %{
      alert_id: alert_id,
      monitor_logical_name: monitor_id,
      generated_at: created_at
    } = alert

    alert
    |> Map.put(:id, alert_id)
    |> Map.put(:account_id, account_id)
    |> Map.put(:monitor_id, monitor_id)
    |> Map.put(:created_at, created_at)
    |> to_pascal_case()
  end
end
