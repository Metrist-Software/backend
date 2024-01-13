defmodule BackendWeb.MonitorDetailLiveRead do
  use BackendWeb, :live_component

  alias BackendWeb.MonitorDetailLive

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(
        %{
          id: _,
          account_id: account_id,
          monitor: monitor,
          snapshot: snapshot,
          analyzer_config: analyzer_config
        } = assigns,
        socket
      ) do
    socket =
      socket
      |> assign(assigns)
      |> assign_pre_mvp_user()
      |> assign(:snapshot, snapshot)

    socket =
      if is_nil(monitor) || is_nil(snapshot) do
        socket
      else
        socket
        |> MonitorDetailLive.load_instances_and_checks(
          account_id,
          monitor.logical_name,
          analyzer_config,
          snapshot
        )
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("start-configuring", _params, socket) do
    send(self(), :start_configuring)
    {:noreply, socket}
  end

  defp assign_pre_mvp_user(socket) do
    assign(socket,
      pre_mvp_user?:
        not is_nil(socket.assigns.current_user) &&
        socket.assigns.account_id
        |> Backend.Projections.get_account!()
        |> pre_mvp_account?()
    )
  end

  defp pre_mvp_account?(%{id: "SHARED"}), do: true

  defp pre_mvp_account?(%{inserted_at: inserted_at}),
    do: Date.compare(inserted_at, ~N[2021-11-01 00:00:00]) == :lt

  defp pre_mvp_account?(_), do: false

  defp monitor_name(monitor) do
    if monitor.name != monitor.logical_name do
      monitor.name
    else
      Backend.Docs.Generated.Monitors.name(monitor.logical_name)
    end
  end
end
