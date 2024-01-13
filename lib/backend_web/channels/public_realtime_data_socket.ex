defmodule BackendWeb.PublicRealtimeDataSocket do
  use Phoenix.Socket

  channel "public_realtime_data:landing_page", BackendWeb.LandingPageTelemetryChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: id()
  def id(), do: "public_realtime_data:landing_page"
end

defmodule BackendWeb.LandingPageTelemetryChannel do
  alias Domain.Monitor.Events.TelemetryAdded
  use Phoenix.Channel

  @monitors_to_subscribe ~w(awsecs awseks awselb awslambda awsrds awsroute53 cognito
    ec2 s3 sqs azureaks azureblob azurecdn azuredb azurefncs azuresql azurevm
    gcpcloudstorage gcpcomputeengine gke authzero avalara braintree circleci
    cloudflare easypost fastly github gcal gmaps heroku hubspot jira npm nuget
    pubnub sendgrid snowflake stripe twiliovid zoom)

  @message_limit 500

  def join("public_realtime_data:landing_page", _message, socket) do
    for topic <- pubsub_topics() do
      Backend.PubSub.subscribe(topic)
    end

    {:ok, assign(socket, message_counter: 0)}
  end

  def handle_info(%{event: %TelemetryAdded{} = event}, socket) do
    message = %{
      "timestamp" => event.created_at,
      "check" => event.check_logical_name,
      "instance" => event.instance_name,
      "monitor" => event.monitor_logical_name,
      "value" => event.value
    }

    push(socket, "new-telemetry", message)

    {:noreply,
     socket
     |> increment_message_counter
     |> maybe_unsubscribe}
  end

  # Catch-all handler
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp increment_message_counter(socket) do
    message_counter = socket.assigns.message_counter + 1
    assign(socket, message_counter: message_counter)
  end

  defp maybe_unsubscribe(socket) when socket.assigns.message_counter > @message_limit do
    for topic <- pubsub_topics() do
      Backend.PubSub.unsubscribe(topic)
    end

    socket
  end

  defp maybe_unsubscribe(socket) do
    socket
  end

  defp pubsub_topics() do
    for monitor_logical_name <- @monitors_to_subscribe do
      id = Backend.Projections.construct_monitor_root_aggregate_id("SHARED", monitor_logical_name)
      "Monitor:#{id}"
    end
  end
end
