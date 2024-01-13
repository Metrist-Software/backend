defmodule BackendWeb.Datadog.AuthCompleteLive do
  use BackendWeb, :dd_live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    {:noreply,
     socket
     |> assign(auto_close: params["auto-close"] == "true")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-20 flex justify-center">
      <div class="text-center">
        <h1 class="text-2xl font-extrabold">You are authorized</h1>
        <p class="text-lg pt-2">
          <span :if={@auto_close} phx-hook="CloseWindow" id="closer">This window will close automatically</span>
          <span :if={!@auto_close}>You may now close this tab</span>
        </p>
      </div>
    </div>
    """
  end
end
