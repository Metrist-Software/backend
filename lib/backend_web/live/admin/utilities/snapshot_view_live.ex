defmodule BackendWeb.Admin.Utilities.SnapshotViewLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      state: nil,
      selected_monitor: nil,
      selected_account: nil,
      analyzer_config: nil,
      accounts: Backend.Projections.list_accounts(preloads: [:original_user]) |> Enum.sort_by(& String.downcase(&1.name || &1.id)))}
  end

  @impl true
  def handle_event("submit", %{"account" => account, "monitor_name" => monitor}, socket) do
    case Backend.RealTimeAnalytics.Analysis.lookup_child(account, monitor) do
      nil -> {:noreply, assign(socket, state: "Not found", monitor: monitor, account: account)}
      pid -> {:noreply, assign(socket, state: pretty(:sys.get_state(pid).current_snapshot), monitor: monitor, account: account, analyzer_config: pretty(:sys.get_state(pid).analyzer_config))}
    end
  end

  @impl true
  def handle_event("select-account", %{"account" => "" }, socket), do: {:noreply, assign(socket, selected_account: nil, seleted_monitor: nil, state: nil, analyzer_config: nil)}
  def handle_event("select-account", %{"account" => account }, socket) do

    {:noreply, assign(socket,
      selected_account: account,
      selected_monitor: nil,
      monitor_configs: [],
      monitors:
        Backend.Projections.list_monitors(account, :monitor_configs)
      )
    }
  end

  def handle_event("select-monitor", %{"monitor" => "" }, socket), do: {:noreply, assign(socket, seleted_monitor: nil, state: nil, analyzer_config: nil)}
  def handle_event("select-monitor", %{"monitor" => monitor}, socket) do
    case Backend.RealTimeAnalytics.Analysis.lookup_child(socket.assigns.selected_account, monitor) do
      nil -> {:noreply, assign(socket, state: "Not found", selected_monitor: monitor)}
      pid -> {:noreply, assign(socket, state: pretty(:sys.get_state(pid).current_snapshot), selected_monitor: monitor, analyzer_config: pretty(:sys.get_state(pid).analyzer_config))}
    end
  end

  defp pretty(obj) do
    inspect(obj, limit: :infinity, pretty: true)
  end
end
