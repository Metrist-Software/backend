defmodule BackendWeb.Datadog.StartLive do
  use BackendWeb, :dd_live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
