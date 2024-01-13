defmodule Backend.Notifications.WebhookHandler do
  @event_type Domain.NotificationChannel.Events.attempt_type("webhook")

  use Backend.Notifications.Handler,
    event_type: @event_type

  @impl true
  def get_response(req), do: HTTPoison.request(req)

  @impl true
  def make_request(_event, %Backend.Projections.Dbpa.Alert{is_instance_specific: false}),
    do: :skip

  def make_request(event, alert) do
    %HTTPoison.Request{
      method: :post,
      url: event.channel_identity,
      body: make_body(alert),
      headers: %{
        "content-type" => "application/json",
        "user-agent" => "Metrist Webhook Bot/1.0"
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
    |> maybe_add_headers(event)
  end

  @spec to_pascal_case(any) :: any
  def to_pascal_case(value = %NaiveDateTime{}), do: value

  def to_pascal_case(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> to_pascal_case()
  end

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

  def to_pascal_case(value) when is_list(value) do
    Enum.map(value, &to_pascal_case/1)
  end

  def to_pascal_case(value) do
    value
  end

  def make_body(alert) do
    body = %{
      "MonitorId" => alert.monitor_logical_name,
      "MonitorName" => alert.monitor_name,
      "AffectedRegions" => alert.affected_regions,
      "AffectedChecks" => alert.affected_checks
    }

    body
    |> to_pascal_case
    |> Jason.encode!
  end

  defp maybe_add_headers(request, %{channel_extra_config: extra_config})
       when extra_config in [nil, ""],
       do: request

  defp maybe_add_headers(request, event) do
    additional_headers = get_additional_headers(event)
    %HTTPoison.Request{request |
                       headers: Map.merge(request.headers, additional_headers)
    }
  end

  defp get_additional_headers(event) do
    case Map.fetch(event.channel_extra_config, :AdditionalHeaders) do
      {:ok, additional_headers} ->
        ensure_map(additional_headers)
      _ -> %{}
    end
  end

  defp ensure_map(additional_headers) when is_map(additional_headers), do: additional_headers
  defp ensure_map(additional_headers) when is_binary(additional_headers), do: Jason.decode!(additional_headers)
end
