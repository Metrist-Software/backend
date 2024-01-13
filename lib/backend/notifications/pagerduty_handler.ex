defmodule Backend.Notifications.PagerDutyHandler do
  alias Backend.Projections.Dbpa.Alert

  @event_type Domain.NotificationChannel.Events.attempt_type("pagerduty")
  @pd_endpoint "https://events.pagerduty.com/v2/enqueue"

  use Backend.Notifications.Handler,
    event_type: @event_type

  # Kept public so we can test these directly

  @impl true
  def get_response(req), do: HTTPoison.request(req)

  @impl true
  def make_request(_event, %Backend.Projections.Dbpa.Alert{is_instance_specific: false}),
    do: :skip

  def make_request(event, alert) do
    %HTTPoison.Request{
      method: :post,
      url: @pd_endpoint,
      body: make_body(event, alert),
      headers: %{
        "content-type" => "application/json; charset=\"utf-8\"",
        "user-agent" => "Metrist PagerDuty Bot/1.0"
      },
      options: [
        timeout: 5_000,
        recv_timeout: 5_000,
        recv_timeout: 5_000,
        follow_redirect: true,
        max_redirect: 3,
        max_body_length: 10240
      ]
    }
  end

  def make_body(event, alert) do
    is_autoresolve = Map.get(event.channel_extra_config || %{}, :AutoResolve, false)
    is_resolve = alert.state == :up
    event_action = event_action(is_autoresolve, is_resolve)

    %{
      routing_key: event.channel_identity,
      dedup_key: alert.correlation_id,
      event_action: event_action,
      payload: make_payload(event, alert)
    }
    |> Jason.encode!()
  end

  def event_action(_is_autoresolve = true, _is_resolve = true), do: "resolve"
  def event_action(_, _), do: "trigger"

  def make_payload(event, alert) do
    %{
      source: List.first(alert.affected_regions),
      severity: severity(event, alert),
      summary: summary(alert)
    }
  end

  def severity(event, %Alert{state: :down}) do
    Map.get(event.channel_extra_config || %{}, :DownSeverity, "error")
  end

  def severity(event, %Alert{state: :degraded}) do
    Map.get(event.channel_extra_config || %{}, :DegradedSeverity, "warning")
  end

  def severity(_, _), do: "info"

  def summary(alert) do
    case Map.get(alert.formatted_messages || %{}, "pagerduty") do
      nil ->
        "#{alert.monitor_name} is in a #{alert.state} state"

      msg ->
        msg
    end
  end
end
