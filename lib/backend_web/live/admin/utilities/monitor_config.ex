defmodule BackendWeb.Admin.Utilities.MonitorConfig do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "View Monitor Config",
        accounts: Backend.Projections.list_accounts(preloads: [:original_user]) |> Enum.sort_by(& String.downcase(&1.name || &1.id)),
        monitors: [],
        selected_account: nil,
        selected_monitor: nil,
        monitor_configs: []
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">View Monitor Config</h2>
        <p class="mb-5">This admin page will show the decrypted extra_config values</p>

        <form>
        Account
          <select id="account" name="account" phx-change="account" required>
            <%= options_for_select([{"Please select an account", nil} | Enum.map(@accounts, fn acc -> {BackendWeb.Helpers.get_account_name_with_id(acc), acc.id} end)], @selected_account) %>
          </select>

          <%= if @selected_account do %>
            Monitor
            <select id="monitor" name="monitor" phx-change="monitor" required>
              <%= options_for_select([{"Please select a monitor", nil} | BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false)],  @selected_monitor) %>
            </select>
          <% end %>
        </form>
        <%= if @selected_monitor do %>
          <div id="results" class="mt-5 min-w-min">
            <%= for config <- @monitor_configs do %>
            <div class="grid grid-cols-[max-content_1fr] gap-4">
              <div class="font-bold text-right">Config ID:</div><div><%= "#{config.id}" %></div>
              <div class="font-bold text-right">Interval Seconds:</div><div><%= "#{config.interval_secs}" %></div>
              <div class="font-bold text-right">Run Groups:</div><div><%= "#{pretty config.run_groups}" %></div>
              <div class="font-bold text-right">Run Specification:</div><div><%= "#{pretty config.run_spec}" %></div>
              <div class="font-bold text-right">Steps:</div><div><%= "#{pretty config.steps}" %></div>
              <div class="font-bold text-right">Decrypted Extra Config:</div><div><%= "#{pretty get_decrypted_extra_config(config.extra_config)}" %></div>
              <.button label="Remove Config" phx-click="remove" phx-value-monitor={@selected_monitor} phx-value-account={@selected_account} phx-value-config={config.id}/>
            </div>

            <code class="bg-gray-100 text-pink-700 dark:bg-auto"><%= "mix metrist.set_extra_config -c #{config.id} #{get_extra_config_mix_task_args(config.extra_config)} -e #{System.get_env("ENVIRONMENT_TAG")} --monitor-logical-name=#{config.monitor_logical_name}" %></code>

            <hr />
            <% end %>
          </div>
        <% end %>

      </div>
    """
  end

  defp get_extra_config_mix_task_args(nil), do: ""
  defp get_extra_config_mix_task_args(extra_config) do
    extra_config
    |> get_decrypted_extra_config()
    |> Map.to_list()
    |> Enum.map(fn {key, value} -> " --config \"#{key}\"=\"#{value |> String.replace("$", "\\$")}\"" end)
  end

  @impl true
  def handle_event("account", %{"_target" => ["account"], "account" => ""}, socket), do: {:noreply, assign(socket, selected_account: nil, seleted_monitor: nil, monitor_configs: [])}
  def handle_event("account", %{"_target" => ["account"], "account" => account}, socket) do
    {:noreply, assign(socket,
      selected_account: account,
      selected_monitor: nil,
      monitor_configs: [],
      monitors:
        Backend.Projections.list_monitors(account, :monitor_configs)
        |> Enum.filter(fn monitor -> length(monitor.monitor_configs) > 0 end)
      )
    }
  end

  def handle_event("monitor", %{"_target" => ["monitor"], "monitor" => ""}, socket), do: {:noreply, assign(socket, seleted_monitor: nil, monitor_configs: [])}
  def handle_event("monitor", %{"_target" => ["monitor"], "monitor" => monitor}, socket) do
    configs = Backend.Projections.get_monitor(socket.assigns.selected_account, monitor, :monitor_configs).monitor_configs
    {:noreply, assign(socket,
      selected_monitor: monitor,
      monitor_configs: configs)
    }
  end

  def handle_event("remove", %{"account" => account_id, "monitor" => monitor, "config" => config_id}, socket) do
    command = %Domain.Monitor.Commands.RemoveConfig{
      id: Backend.Projections.construct_monitor_root_aggregate_id(account_id, monitor),
      config_id: config_id
    }

    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(socket, command)
    # rerender
    {:noreply, assign(socket,
      selected_monitor: nil)
    }
  end

  defp get_decrypted_extra_config(nil), do: nil
  defp get_decrypted_extra_config(extra_config) do
    extra_config |> Enum.map(fn {k, v} -> {k, Domain.CryptUtils.decrypt_field(v)} end) |> Map.new()
  end

  defp pretty(obj) do
    inspect(obj, limit: :infinity, pretty: true)
  end
end
