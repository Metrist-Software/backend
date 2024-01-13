defmodule BackendWeb.MonitorsLive do
  use BackendWeb, :live_view

  alias Backend.Projections

  @monitor_logos %{
    "aws" => "aws-logo.svg",
    "azure" => "azure-logo.svg",
    "gcp" => "gcp-logo.svg"
  }

  @impl true
  def mount(params, session, socket) do
    limit_memory()

    account_id = session["current_user"].account_id
    account = Projections.get_account!(account_id)

    displayed_monitors = Projections.list_monitors(account_id, [:monitor_tags])
    |> Map.new(&{&1.logical_name, with_snapshot(&1, account_id)})

    status_page_names = Projections.status_pages()
      |> Enum.map(fn sp -> sp.name end)

    initial_filter = case params do
      %{"tag" => tag} -> {:parent, tag}
      %{"id" => id} -> {:child, id}
      _ -> nil
    end

    # Initialize all from manifest data
    all_monitors =
      Backend.Docs.Generated.Monitors.all()
      |> Enum.map(fn mon -> %Projections.Dbpa.Monitor {
        logical_name: mon,
        name: Backend.Docs.Generated.Monitors.name(mon),
        monitor_tags: %Projections.Dbpa.MonitorTags {
          monitor_logical_name: mon,
          tags: Backend.Docs.Generated.Monitors.monitor_groups(mon)
        }
      } end)
      |> Map.new(&{&1.logical_name, &1})

    socket =
      socket
      |> assign(
        is_configuring: false,
        all_monitors: all_monitors,
        account_name: Projections.Account.get_account_name(account),
        displayed_monitors: displayed_monitors,
        account_monitors: displayed_monitors,
        original_account_monitors: displayed_monitors,
        status_page_names: status_page_names,
        grouped_monitors: [],
        filter_list_group_data: [],
        initial_list_group_filter: initial_filter,
        page_title: "Dependencies")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
      |> assign(actual_query_params: params)

   {:noreply, socket}
  end

  defp apply_action(socket, :index, params) do
    assign(socket, is_configuring: false, displayed_monitors: socket.assigns.account_monitors)
    |> assign_grouped_monitors_and_count(params)
  end

  defp apply_action(socket, :configure, params) do
    case socket.assigns.current_user.is_read_only do
      true -> redirect(socket, to: "/")
      _ -> assign(socket, is_configuring: true, displayed_monitors: socket.assigns.all_monitors)
      # Show all the monitors when configuring regardless of status
      |> assign_grouped_monitors_and_count(Map.put(params, "status", "all"))
    end
  end

  defp assign_grouped_monitors_and_count(%{assigns: assigns} = socket, params) do
    %{displayed_monitors: displayed_monitors} = assigns

    search = case params do
      %{"id" => _id}  -> Map.drop(params, ["tag"])
      %{"tag" => _tag} -> Map.drop(params, ["id"])
      _ -> params
    end
    |> Map.put_new("status", "all")

    grouped_monitors = group_monitors(displayed_monitors, search)
    unfiltered_grouped_monitors = group_monitors(displayed_monitors)
    {grouped_monitors, search} = maybe_override_search_and_list(grouped_monitors, unfiltered_grouped_monitors, search, Map.get(params, "status"))

    assign(socket,
      grouped_monitors: grouped_monitors,
      search: search,
      filter_list_group_data: monitor_listgroup_data(unfiltered_grouped_monitors)
    )
  end

  @impl true
  def handle_event("toggle-monitor", params, socket) do
    is_selected = Map.has_key?(params, "value")

    selected_monitors = toggle_account_monitor(socket.assigns.all_monitors[params["logical_name"]], socket, is_selected)

    {:noreply, assign(socket, account_monitors: selected_monitors)}
  end

  def handle_event("toggle-all", params, socket) do
    is_selected = Map.has_key?(params, "value")

    account_monitors =
      case is_selected do
        true -> socket.assigns.all_monitors
        |> Enum.reduce(%{},
        fn {name, m}, acc ->
          Map.put(acc, name, m)
        end)
        false -> %{}
      end

    {:noreply, assign(socket, account_monitors: account_monitors)}
  end

  @impl true
  def handle_event("clear-filters", _, socket) do
    {:noreply, push_patch(socket, to: Routes.monitors_path(socket, :index), replace: true)}
  end

  def handle_event("cancel", _params, socket) do
    socket = assign(socket, %{
      account_monitors: socket.assigns.original_account_monitors
    })

    {:noreply, push_patch(socket, to: Routes.monitors_path(socket, :index, socket.assigns.actual_query_params), replace: true)}
  end

  def handle_event("save", _params, socket) do
    cmd = %Domain.Account.Commands.SetMonitors{
      id: socket.assigns.current_user.account_id,
      monitors:
        socket.assigns.account_monitors
        |> Enum.map(
          fn {logical_name, monitor} -> %Domain.Account.Commands.MonitorSpec{
            logical_name: logical_name,
            name: monitor.name
          } end
        )
    }

    # Ensure any new monitors have a snapshot even if it's nil, and is subscribed to changes
    account_monitors_with_snapshots =
      socket.assigns.account_monitors
      |> Map.new(fn {logical_name, monitor} -> {logical_name, with_snapshot(monitor, socket.assigns.current_user.account_id)} end)

    case BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd) do
      {:error, _} -> {:noreply, socket}
      _ ->
        socket = assign(socket, %{
          account_monitors: account_monitors_with_snapshots,
          original_account_monitors: account_monitors_with_snapshots
        })

        {:noreply, push_patch(socket, to: Routes.monitors_path(socket, :index), replace: true)}
    end
  end

  @impl true
  def handle_info({:list_group_parent_selected, id, _}, socket) do
    params = socket.assigns.search
    |> Map.delete("id")
    |> Map.put("tag", id)

    {:noreply, push_patch(socket, to: Routes.monitors_path(socket, socket.assigns.live_action, params), replace: true)}
  end

  def handle_info({:list_group_child_selected, id}, socket) do
    params = socket.assigns.search
    |> Map.delete("tag")
    |> Map.put("id", id)

    {:noreply, push_patch(socket, to: Routes.monitors_path(socket, socket.assigns.live_action, params), replace: true)}
  end

  def handle_info(:list_group_select_cleared, socket) do
    params = socket.assigns.search
    |> Map.delete("tag")
    |> Map.delete("id")

    {:noreply, push_patch(socket, to: Routes.monitors_path(socket, socket.assigns.live_action, params), replace: true)}
  end

  def handle_info({:snapshot_state_changed, _acc, monitor_logical_name, monitor_state}, socket) do
    # Ignore edit mode, we're not showing status there anyway.
    {:noreply,
     socket
     |> update_snapshot(monitor_logical_name, monitor_state, :displayed_monitors)
     |> update_snapshot(monitor_logical_name, monitor_state, :original_account_monitors)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # if all monitors are up, then just show all and reset status to "all" if no status was explicitely selected/requested
  def maybe_override_search_and_list(grouped_monitors, unfiltered_grouped_monitors, search, status_param) when is_nil(status_param) do
    case Enum.empty?(grouped_monitors) do
      true -> {unfiltered_grouped_monitors, Map.put(search, "status", "all")}
      false -> {grouped_monitors, search}
    end
  end
  def maybe_override_search_and_list(grouped_monitors, _unfiltered_grouped_monitors, search, status_param) when is_binary(status_param), do: {grouped_monitors, search}

  def image_url(mon) do
    monitor_image_url(short_id(mon))
  end

  defp short_id(mon) do
    String.replace(mon.logical_name, "Monitors/", "")
  end

  def group_monitors(displayed_monitors, options \\ %{}) do
    id = Map.get(options, "id")
    tag = Map.get(options, "tag")
    status = Map.get(options, "status")

    monitors = if id do
      Map.take(displayed_monitors, [id])
    else
      displayed_monitors
    end

    monitors = if status == "issues" do
      Enum.filter(monitors, fn
        {_, %{snapshot: %{state: state}}} when state != :up -> true
        _ -> false
      end)
    else
      monitors
    end

    group_filter = if tag do
      fn monitor_tag -> tag == monitor_tag end
    else
      fn i -> i end
    end

    Enum.reduce(monitors, %{}, fn {logical_name, _m}, acc ->
      groups =
        case Backend.Docs.Generated.Monitors.monitor_groups(logical_name) do
          [] -> ["other"]
          groups -> groups
        end

      groups
      |> Enum.filter(group_filter)
      |> Map.new(&({&1, [logical_name]}))
      |> Map.merge(acc, fn _key, [m1], m2 -> [m1 | m2] end)
    end)
  end

  def grouped_monitors_list(grouped_monitors) do
    Enum.map(Projections.Dbpa.MonitorTags.tag_names(), fn {tag, name} ->
      monitors = Map.get(grouped_monitors, tag, [])
      logo = Map.get(@monitor_logos, tag, "default-logo.svg")

      {tag, name, monitors, logo}
     end)
    |> Enum.reject(&Enum.empty?(elem(&1, 2)))
  end

  @get_snapshot &Backend.RealTimeAnalytics.get_snapshot_or_nil/2

  defp with_snapshot(monitor, account_id, get_snapshot \\ @get_snapshot) do
    # If we want a snapshot, we also want a change subscription.
    Backend.PubSub.subscribe_snapshot_state_changed(account_id, monitor.logical_name)
    snapshot = get_snapshot.(account_id, monitor.logical_name)
    Map.put(monitor, :snapshot, snapshot)
  end

  # public for testing
  def update_snapshot(socket, monitor_logical_name, monitor_state, which, get_snapshot \\ @get_snapshot) do
    monitors = Map.get(socket.assigns, which)
    monitor = Map.get(monitors, monitor_logical_name)
    if monitor != nil and snapshot_state(monitor.snapshot) != monitor_state do
      monitor = with_snapshot(monitor, socket.assigns.current_user.account_id, get_snapshot)
      assign(socket, which, Map.put(monitors, monitor_logical_name, monitor))
    else
      socket
    end
  end

  def monitor_listgroup_data(grouped_monitors) do
    Enum.map(grouped_monitors, fn {group, logical_names} ->
        group_label = Projections.Dbpa.MonitorTags.tag_name(group)
        children = Enum.map(logical_names, fn name -> %{
          id: name,
          label: Backend.Docs.Generated.Monitors.name(name)
        }
        end)
        %{children: children, id: group, label: group_label}
    end)
  end

  def render_select_by_status_label(status) do
    assigns = %{}
    case status do
      "issues" ->
        ~H"""
        Display <span class="bg-down pill ml-1">Only Issues</span>
        """
      _ ->
        ~H"""
        Display <span class="bg-healthy pill ml-1">All</span>
        """
    end
  end

  def no_results_message(status) do
    case status do
      "issues" ->
        """
        All monitors are healthy!
        <a phx-click="clear-filters" class="hover:font-bold underline hover:cursor-pointer">
          Display all dependencies.
        </a>
        """
      _ ->
        """
        <p>
        Welcome to Metrist! In order to get started, please <a class="underline hover:font-bold" href="https://docs.metrist.io/guides/orchestrator-installation.html">download and install Metrist</a> in your primary cloud environment. Then, <a class="underline hover:font-bold" href="https://docs.metrist.io/monitors/">configure Metrist</a> to monitor your first service so we can begin collecting metrics about your specific experience with a cloud dependency. For assistance, <a class="underline hover:font-bold" href="https://calendly.com/jmartenspdx/metrist-consultation">schedule a consultation</a>.
        </p>

        <p class="mt-4">
        If you have done this already, just wait a bit for data to arrive! Otherwise, contact our support team for help.
        </p>
        """
    end
    |> raw()
  end

  defp toggle_account_monitor(monitor, socket, false) do
    Map.delete(socket.assigns.account_monitors, monitor.logical_name)
  end

  defp toggle_account_monitor(monitor, socket, true) do
    Map.put(socket.assigns.account_monitors, monitor.logical_name, monitor)
  end

  defp monitor_is_selected?(mon, monitors) do
    Enum.any?(monitors, fn {_i, m} -> m.logical_name == mon.logical_name end)
  end

  defp header_id(name) do
    "#{String.replace(name, ~r"\s", "")}-header"
  end
end
