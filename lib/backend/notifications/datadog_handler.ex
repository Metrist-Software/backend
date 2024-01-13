defmodule Backend.Notifications.DatadogHandler do
  @event_type Domain.NotificationChannel.Events.attempt_type("datadog")

  use Backend.Notifications.Handler,
    event_type: @event_type

  @datadog_sites %{
    "us" => "https://api.datadoghq.com/api/v1/check_run",
    "us3" => "https://api.us3.datadoghq.com/api/v1/check_run",
    "us5" => "https://api.us5.datadoghq.com/api/v1/check_run",
    "eu" => "https://api.datadoghq.eu/api/v1/check_run"
  }

  @datadog_severities %{
    ok: 0,
    warn: 1,
    critical: 2,
    unknown: 3
  }

  # Kept public so we can test these directly

  @impl true
  def get_response(req) do
    HTTPoison.request(req)
  end

  @impl true
  def make_request(_event, %Backend.Projections.Dbpa.Alert{is_instance_specific: false}),
    do: :skip

  def make_request(event, alert) do
    site = Map.get(event.channel_extra_config, :DatadogSite, "us")
    url = Map.get(@datadog_sites, site)

    Enum.map(alert.affected_checks, fn check ->
      %HTTPoison.Request{
        method: :post,
        url: url,
        body: make_body(event, alert, check),
        headers: %{
          "content-type" => "application/json",
          "user-agent" => "Metrist Datadog Bot/1.0",
          "DD-API-KEY" => event.channel_identity
        },
        options: [
          timeout: 5_000,
          recv_timeout: 5_000,
          recv_timeout: 5_000,
          follow_redirect: true,
          max_redirect: 3,
          max_body_length: 10_240,
        ]
      }
    end)
  end

  def make_body(event, alert, check) do
    check_id = check["check_id"]
    %{
      check: "metrist.monitor.status",
      host_name: List.first(alert.affected_regions),
      status: get_severity_from_alert_and_config(alert, event.channel_extra_config),
      tags: ["monitor:#{alert.monitor_logical_name}", "check:#{check_id}"]
    }
    |> Jason.encode!()
  end

  defp get_severity_from_alert_and_config(alert, config) do
    case alert.state do
      :down ->
        configured_severity = config
        |> Map.get(:DownSeverity)
        |> convert_severity()

        Map.get(@datadog_severities, configured_severity, @datadog_severities.critical)
      :degraded ->
        configured_severity = config
        |> Map.get(:DegradedSeverity)
        |> convert_severity()

        Map.get(@datadog_severities, configured_severity, @datadog_severities.warn)
      :up ->
        @datadog_severities.ok
      _ ->
        @datadog_severities.unknown
    end
  end

  defp convert_severity(sev) when is_binary(sev) do
    sev
    |> String.downcase()
    |> String.to_existing_atom()
  end
  defp convert_severity(sev), do: sev
end
