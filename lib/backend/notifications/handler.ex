defmodule Backend.Notifications.Handler do
  require Logger

  @type event :: map()
  @type request :: term()
  @type metadata :: map()
  @type response :: {:ok, term()} | {:error, term()}

  # Optional callbacks
  @callback response_ok?(response) :: boolean()
  @callback response_status_code(response) :: integer()

  # Required callbacks
  @callback make_request(event, %Backend.Projections.Dbpa.Alert{}) :: :skip | request
  @callback get_response(request) :: response

  @optional_callbacks response_ok?: 1, response_status_code: 1

  defmacro __using__(opts \\ []) do
    event_type = Keyword.get(opts, :event_type)

    quote do
      @behaviour Backend.Notifications.Handler

      import Backend.Projectors.TypeStreamLinker.Helpers, only: [type_stream: 1]

      use Commanded.Event.Handler,
        application: Backend.App,
        name: __MODULE__,
        start_from: :current,
        # This is the global amount of parallel senders of the given type we will employ. Note that we
        # do random partition selection, which is fine as other code is responsible for ordering.
        concurrency: 10,
        subscribe_to: type_stream(unquote(event_type))

      alias Backend.Notifications.Handler

      @impl true
      def handle(e = %unquote(event_type){}, metadata) do
        Backend.Notifications.Handler.do_handle(e, metadata, __MODULE__)
      end
    end
  end

  @doc """
  Handle an event by using the passed in a module containing request and response functions
  to actually notify something and decide what to do next based on the response.
  """
  def do_handle(e, metadata, handler_module) do
    alert = Backend.Projections.get_alert_by_id(e.account_id, e.alert_id)

    cmds = process_request(e, alert, handler_module)

    Enum.each(cmds, fn cmd ->
      Backend.App.dispatch_with_actor(Backend.Auth.Actor.backend_code(), cmd,
        causation_id: metadata.event_id,
        correlation_id: metadata.correlation_id
      )
    end)

    :ok
  end

  def process_request(e, nil, _handler_module) do
    # We've been asked to process an alert but it hasn't saved to the database yet
    # Schedule a retry on it (which will happen 60s later)
    Logger.info("Asked to deliver alert, but alert hasn't made it to the db yet on account #{e.account_id}, with alert id: #{e.alert_id}. Scheduling a retry.")
    [retry_delivery(e)]
  end

  def process_request(e, alert, handler_module) do
    case handler_module.make_request(e, alert) do
      :skip ->
        [complete_delivery(e)]
      request ->
        response = if is_list(request) do
          Enum.map(request, fn req -> handler_module.get_response(req) end)
        else
          handler_module.get_response(request)
        end

        log_attempt = log_subscription_delivery_attempt(e, response, handler_module)

        if response_ok?(response, handler_module) do
          [complete_delivery(e), log_attempt]
        else
          Logger.info("Delivery issue, event is #{inspect(e)}, result is #{inspect(response)}")
          [retry_delivery(e), log_attempt]
        end
    end
  end

  def response_ok?(response, handler_module) do
    if function_exported?(handler_module, :response_ok?, 1) do
      handler_module.response_ok?(response)
    else
      response_ok?(response)
    end
  end
  def response_ok?(response) when is_list(response) do
    Enum.all?(response, &response_ok?/1)
  end
  def response_ok?({:error, _response}), do: false
  def response_ok?({:ok, %{status_code: status}}), do: status in 200..299

  defp complete_delivery(e) do
    %Domain.NotificationChannel.Commands.CompleteDelivery{
      id: e.id,
      alert_id: e.alert_id
    }
  end

  defp retry_delivery(e) do
    %Domain.NotificationChannel.Commands.RetryDelivery{
      id: e.id,
      alert_id: e.alert_id
    }
  end

  defp log_subscription_delivery_attempt(e, response, handler_module) do
    status_code = if function_exported?(handler_module, :response_status_code, 1) do
      handler_module.response_status_code(response)
    else
      response_status_code(response, handler_module)
    end

    %Domain.Account.Commands.AddSubscriptionDeliveryV2{
      id: e.account_id,
      alert_id: e.alert_id,
      subscription_id: e.subscription_id,
      status_code: status_code
    }
  end

  defp response_status_code({:error, _response}, _handler_module), do: 500
  defp response_status_code({:ok, %{status_code: status}}, _handler_module), do: status
  defp response_status_code({:ok, _}, _handler_module), do: 200
  defp response_status_code(response, handler_module) when is_list(response) do
    if response_ok?(response, handler_module), do: 200, else: 500
  end
end
