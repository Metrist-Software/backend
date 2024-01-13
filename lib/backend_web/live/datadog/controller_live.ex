defmodule BackendWeb.Datadog.ControllerLive do
  @moduledoc """
  Controller iFrame for Datadog Metrist App
  """
  use BackendWeb, :dd_live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="controller" phx-hook="DatadogController">
    </div>
    """
  end
end
