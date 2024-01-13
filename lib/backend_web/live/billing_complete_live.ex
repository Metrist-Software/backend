defmodule BackendWeb.BillingCompleteLive do
  use BackendWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, default_assigns(socket)}
  end

  @impl true
  def handle_params(%{"setup_intent" => intent_id, "setup_intent_client_secret" => _client_secret, "redirect_status" => "succeeded"}, _uri, socket) do
    if connected?(socket) do
      status = case Stripe.SetupIntent.retrieve(intent_id, %{}) do
        {:ok, %Stripe.SetupIntent{status: status}} -> status
        {:error, _} -> "error"
      end

      socket = if status == "succeeded" do
        result = Backend.Auth.CommandAuthorization.dispatch_with_auth_check(
          socket,
          %Domain.Account.Commands.CompleteMembershipIntent{
            id: socket.assigns.current_user.account_id,
            callback_reference: intent_id
          },
          returning: :execution_result
        )

        case result do
          {:ok, %{events: [_ | _]}} -> assign(socket, status: "succeeded")
          _ -> assign(socket, status: "error")
        end
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    socket = put_flash(socket, :error, "Sorry, something went wrong")

    {:noreply, socket}
  end

  defp default_assigns(socket) do
    assign(socket,
      hide_breadcrumb: true,
      status: nil)
  end

  @impl true
  def render(assigns=%{status: "succeeded"}) do
    ~H"""
    <div class="font-roboto">
      <header class="mb-8">
        <h2 class="text-3xl">
          Thank you!
        </h2>
      </header>

      <p>Your payment method has been successfuly set up and will be charged shortly</p>
    </div>
    """
  end

  def render(assigns=%{status: nil}) do
    ~H"""
    <div class="font-roboto">
      <.spinner class="inline"/> Processing...
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="font-roboto">
      <p>Sorry, something went wrong. Please <.link navigate="/billing" class="link">try again</.link> or <.link href="mailto:support@metrist.io" class="link">contact us</.link> for support.</p>
    </div>
    """
  end
end
