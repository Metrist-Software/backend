defmodule BackendWeb.Admin.Utilities.ChangeMonitorTag do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Change Monitor Tag",
        accounts: Backend.Projections.list_accounts(preloads: [:original_user]) |> Enum.sort_by(& String.downcase(&1.name || &1.id)),
        monitors: nil,
        selected_account: nil,
        from_tag_options: [],
        tags: Backend.Projections.Dbpa.MonitorTags.get_tag_names
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Change Monitor Tag</h2>
        <p class="m-5">Remove previous tag(s) from a monitor and then add the selected tag to the monitor.</p>

        <form phx-submit="change_monitor_tag">
        Account
          <select id="account" name="account" phx-click="select-account" required>
            <%= options_for_select([{"Please select an account", nil} | Enum.map(@accounts, fn acc -> {BackendWeb.Helpers.get_account_name_with_id(acc), acc.id} end)], @selected_account) %>
          </select>

          <%= if @selected_account do %>
            Monitor
            <select id="monitor" name="monitor" phx-click="update-from-tags" required>
              <%= options_for_select(BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false), get_selected_monitor(@monitors)) %>
            </select>

            From Tag
            <select id="from_tag" name="from_tag" required>
              <%= options_for_select(@from_tag_options, get_selected_from_tag(@from_tag_options)) %>
            </select>

            To Tag
            <select id="to_tag" name="to_tag" required>
              <%= options_for_select(@tags, List.first(@tags)) %>
            </select>

            <button type="submit" class={"#{button_class()} mt-3"}phx-disable-with="Loading...">Change Tag</button>
          <% end %>
        </form>
      </div>
    """
  end

  defp get_tags(nil) do
    nil
  end
  defp get_tags(monitor) do
    case Backend.Projections.Dbpa.MonitorTags.get_tags_for_monitor(monitor) do
      %{tags: tags} -> tags
      _ -> []
    end
  end

  defp get_selected_monitor([]), do: nil
  defp get_selected_monitor(monitors), do: List.first(monitors).logical_name

  defp get_selected_from_tag([]), do: nil
  defp get_selected_from_tag(tags), do: List.first(tags)

  @impl true
  def handle_event("select-account", %{"value" => "" }, socket), do: {:noreply, assign(socket, selected_account: nil)}
  def handle_event("select-account", %{"value" => account }, socket) do
    monitors = Backend.Projections.list_monitors(account)
    {:noreply, assign(
      socket,
      selected_account: account,
      monitors: monitors,
      from_tag_options: monitors |> get_selected_monitor |> get_tags
    )}
  end

  # when a monitor is selected, update from tag options
  def handle_event("update-from-tags", %{"value" => nil }, socket), do: {:noreply, assign(socket, from_tag_options: nil)}
  def handle_event("update-from-tags", %{"value" => monitor }, socket) do
    {:noreply, assign(socket, from_tag_options: get_tags(monitor))}
  end

  def handle_event("change_monitor_tag", %{"to_tag" => ""}, socket), do: {:noreply, socket |> clear_flash() |> put_flash(:error, "Must provide a to tag")}
  def handle_event("change_monitor_tag", %{"from_tag" => ""}, socket), do: {:noreply, socket |> clear_flash() |> put_flash(:error, "Must provide a from tag")}
  def handle_event("change_monitor_tag", %{"account" => account, "monitor" => monitor, "from_tag"
   => from_tag, "to_tag" => to_tag}, socket) do
    cmd = %Domain.Monitor.Commands.ChangeTag {
      id: Backend.CommandTranslator.translate_id(account, monitor),
      from_tag: from_tag,
      to_tag: to_tag
    }
    BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)

    {
      :noreply,
      assign(
        socket,
        current_command: nil,
        from_tag_options: monitor |> get_tags
      )
      |> clear_flash()
      |> put_flash(:info, "Succesfully updated #{monitor} for account #{account}")
    }
  end
end
