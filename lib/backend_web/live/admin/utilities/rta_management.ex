defmodule BackendWeb.Admin.Utilities.RtaManagement do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "RTA Management",
        account_id: nil,
        monitor_id: nil,
        analysis_data: nil,
        restart_analysis_disabled: true,
        mcis: []
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">RTA Management</h2>

        <.live_component
          module={BackendWeb.Components.AccountMonitorSelection}
          id="am-select"
        />

        <.button disabled={!@monitor_id} label="Get MCI Processes" phx-click="get_mcis" />
        <.button disabled={!@monitor_id} label="Inspect Analysis Process" phx-click="inspect_analysis" />
        <.button label="Reinitialize Loader" color="warning" phx-click="reinit_loader" />

        <div :if={!Enum.empty?(@mcis)} class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-5">
          <.card :for={{mci, state} <- @mcis}>
            <.card_content heading={"#{elem(state.mci, 2)} - #{elem(state.mci, 3)}"}>
              <.accordion class="w-full">
                <:item heading="State">
                  <pre phx-hook="Highlight" id={inspect(state.mci)} class="overflow-x-scroll"><code class="elixir"><%= inspect(state, limit: :infinity, pretty: true) %></code></pre>
                </:item>
              </.accordion>
            </.card_content>

            <.card_footer>
              <.button
                label="Stop Process"
                color="danger"
                phx-click="stop_mci"
                phx-value-account={elem(mci,0)}
                phx-value-monitor={elem(mci,1)}
                phx-value-check={elem(mci,2)}
                phx-value-instance={elem(mci,3)}
              />
            </.card_footer>
          </.card>
        </div>

        <div :if={@analysis_data} id="code" class="mt-5" phx-hook="Highlight">
          <.button disabled={@restart_analysis_disabled} label="Restart Analysis Process" color="danger" phx-click="restart_analysis" class="mb-3"/>

          <pre class="bg-gray-200 dark:bg-gray-800 p-3 rounded"><code class="elixir"><%= inspect(@analysis_data, limit: :infinity, pretty: true) %></code></pre>
        </div>
      </div>
    """
  end

  @impl true
  def handle_info({:am_selected, account_id, monitor_id}, socket) do
    {:noreply, assign(socket, account_id: account_id, monitor_id: monitor_id, restart_analysis_disabled: true)}
  end

  @impl true
  def handle_event("get_mcis", _, socket) do
    socket = socket
    |> do_get_mcis()
    |> assign(analysis_data: nil)

    {:noreply, socket}
  end

  def handle_event("inspect_analysis", _, socket) do
    socket = socket
    |> do_inspect_analysis()
    |> assign(mcis: [], restart_analysis_disabled: false)

    {:noreply, socket}
  end

  def handle_event("stop_mci", %{"account" => account, "monitor" => monitor, "check" => check, "instance" => instance}, socket) do
    mci = {account, monitor, check, instance}
    Backend.RealTimeAnalytics.SwarmSupervisor.stop_child(mci)

    {:noreply, do_get_mcis(socket)}
  end

  def handle_event("restart_analysis", _, socket) do
    %{account_id: account_id, monitor_id: monitor_id} = socket.assigns
    opts = [account_id: account_id, monitor_logical_name: monitor_id]
    Backend.RealTimeAnalytics.SwarmSupervisor.stop_analysis_child(opts)

    monitor = Backend.Projections.get_monitor(account_id, monitor_id, [:checks, :monitor_configs])
    analyzer_config = Backend.Projections.get_analyzer_config(account_id, monitor_id)

    Backend.RealTimeAnalytics.Loader.load_and_start_analysis(account_id, monitor, analyzer_config)

    {:noreply, do_inspect_analysis(socket)}
  end

  def handle_event("reinit_loader", _data, socket) do
    Backend.RealTimeAnalytics.Loader.request_initialization()

    socket = put_flash(socket, :info, "Loader initialization requested")

    {:noreply, socket}
  end

  defp do_get_mcis(socket) do
    mcis = Backend.RealTimeAnalytics.SwarmSupervisor.get_all_mci_processes_for_account_and_monitor(socket.assigns.account_id, socket.assigns.monitor_id)
    |> Enum.map(fn pid ->
      state = :sys.get_state(pid)
      {state.mci, state}
    end)

    assign(socket, mcis: mcis)
  end

  defp do_inspect_analysis(socket) do
    case Backend.RealTimeAnalytics.Analysis.lookup_child(socket.assigns.account_id, socket.assigns.monitor_id) do
      pid when is_pid(pid) -> assign(socket, analysis_data: :sys.get_state(pid))
      _ -> put_flash(socket, :error, "Could not get analysis state")
    end
  end
end
