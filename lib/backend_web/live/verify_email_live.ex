defmodule BackendWeb.VerifyEmailLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        resend_disabled: false,
        hide_breadcrumb: true)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl mb-5">
        Please verify your email address
      </h1>

      <button phx-click="resend" class="btn btn-green" disabled={@resend_disabled}>
        Resend verification email
      </button>

      <button phx-click="reverify" class="btn btn-green">
        I am already verified
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("resend", _params, socket) do
    Process.send_after(self(), :enable_resend, 30000)

    Backend.UserFromAuth.resend_verification_mail(socket.assigns.current_user)
    socket = socket
    |> assign(resend_disabled: true)
    |> put_flash(:info, "We have sent the verification mail again. Please check your mailbox and follow the instructions in the mail to verify your email address.")

    {:noreply, socket}
  end

  def handle_event("reverify", _params, socket) do
    socket = if Backend.UserFromAuth.is_verified(socket.assigns.current_user) do
      redirect(socket, to: "/auth/reauth")
    else
      put_flash(socket, :error, "It does not look like you have already verified your email address. Please verify your email address using the instructions in the email we sent or use the \"Resend Verification Email\" button below to send it again.")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:enable_resend, socket) do
    socket = assign(socket, resend_disabled: false)
    {:noreply, socket}
  end
end
