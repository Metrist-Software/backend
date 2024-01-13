defmodule BackendWeb.Helpers do
  @moduledoc """
  Miscellaneous helpers for the WebUI, like components that are too
  small to warrant their own, well, component.
  """

  use Phoenix.HTML
  use Phoenix.Component
  require Logger

  defmodule Svg do
    # This generates a ton of large functions and scans directories at compile time. By having
    # it just once here, we optimize compilation and final binary size a bit. Gets imported
    # from the BackendWeb view helpers method so the svg_image functions are available pretty
    # much everywhere.
    use PhoenixInlineSvg.Helpers
  end

  def step_progress(steps, step) do
    steps =
      steps
      |> Enum.with_index()
      |> Enum.map(fn {stp, i} ->
        cls =
          if i <= step do
            "font-bold border-teal-500 dark:border-teal-500"
          else
            "dark:border-gray-600"
          end

        {stp, cls}
      end)

    snippet = """
    <ul class="flex flex-col md:flex-row space-y-2 md:space-y-0 md:space-x-4 mb-5">
    <%= for {stp, cls} <- steps do %>
      <li class="md:py-2 pl-3 md:pl-0 md:pr-5 border-l-2 md:border-l-0 md:border-b-2 <%= cls %>">
        <%= stp %>
      </li>
    <% end %>
    </ul>

    """
    {:safe, EEx.eval_string(snippet, step: step, steps: steps)}
  end

  def button_class(name \\ "primary", disabled \\ false) do
    specifics =
      if disabled do
        "btn-disabled"
      else
        case name do
          "secondary" ->
            "btn-outline"

          "primary" ->
            "btn-green"

          "large" ->
            "btn-green btn-lg"

          "danger" ->
            "btn-red"

          "warning" ->
            "btn-yellow"
          _ ->
            ""
        end
      end

    "btn #{specifics}"
  end

  # The styles for this component came from https://github.com/petalframework/petal_components/blob/d3e74e3bdb7ddcc788ec66ad3a51bcdadd503550/lib/petal_components/form.ex#L361
  # MET-847 uses PetalComponents switch but the Monitor Configure screen uses the old style, so i copied over the new style
  def pill_switch(assigns) do
    assigns = assigns
    |> assign_new(:enabled, fn -> false end)

    ~H"""
    <label class="relative inline-flex items-center justify-center flex-shrink-0 w-10 h-5 group">
      <input
        class="absolute w-10 h-5 bg-white border-none rounded-full cursor-pointer peer checked:border-0 checked:bg-transparent checked:focus:bg-transparent checked:hover:bg-transparent dark:bg-gray-800"
        type="checkbox" name={@name} checked={@enabled} />
      <span class="absolute h-6 mx-auto transition-colors duration-200 ease-in-out bg-gray-200 border rounded-full pointer-events-none w-11 dark:bg-gray-700 dark:border-gray-600 peer-checked:bg-primary-500"></span>
      <span class="absolute left-0 inline-block w-5 h-5 transition-transform duration-200 ease-in-out transform translate-x-0 bg-white rounded-full shadow pointer-events-none peer-checked:translate-x-5 ring-0 "></span>
    </label>
    """
  end

  @doc """
  Renders a list group

  # Example

  ```elixir
    <.listgroup groups={[%{
      id: "group1",
      label: "Group1",
      children: [%{
        id: "child1",
        label: "Child1",
      },%{
        id: "child1",
        label: "Child1",
      }]
     }]}>
      <:parent :let={parent} class="text-white">
        <%= parent.label %>
      </:parent>
      <:child :let={child} class="w-full">
        <%= child.label %>
      </:child>
    </.listgroup>
  ```
  Renders

  ```html
    <ul>
      <li>
        <span class="text-white">Group1</span>
        <ul>
          <li class="w-full">Child1</li>
          <li class="w-full">Child2</li>
        </ul>
      </li>
    </ul>
  ```
  """
  def listgroup(assigns) do
    # We can assume that there will always be one parent and child slot
    parent_slot = assigns
      |> Map.get(:parent, [])
      |> List.first()

    child_slot = assigns
      |> Map.get(:child, [])
      |> List.first()

    list_container_attributes = get_attrs(assigns, [:class])
    list_item_attributes = get_attrs(assigns, [:list_item_class])
    child_attributes = get_attrs(child_slot, [:class, :role])
    parent_attributes = get_attrs(parent_slot, [:class, :role])

    assigns =
      assign(assigns,
        child_slot: child_slot,
        parent_slot: parent_slot,
        list_container_attributes: list_container_attributes,
        child_attributes: child_attributes,
        parent_attributes: parent_attributes,
        list_item_attributes: list_item_attributes
      )

    ~H"""
    <ul {@list_container_attributes}>
      <%= for group <- @groups do %>
        <li {@list_item_attributes}>
          <span {@parent_attributes}><%= render_slot(@parent, group) %></span>
          <%= for child <- Map.get(group, :children, []) do %>
            <ul {@child_attributes}>
              <%= render_slot(@child_slot, child) %>
            </ul>
          <% end %>
        </li>
      <% end %>
    </ul>
    """
  end

  defp get_attrs(nil, _attrs), do: []
  defp get_attrs(slot, attrs) do
    Enum.map(attrs, & {&1, Map.get(slot, &1)})
    |> Enum.filter(fn {_, value} -> value end)
  end

  @doc """
  Renders a select field

  # Options
  - phx_ref - Gets assigned to `phx-value-ref` to the list item. You can use this value when doing a pattern match in handle_event
  - phx_click - Gets assigned to `phx-click` to the list item.
  - phx_value_key (default: `:id`) - The key to be used when assigning value to `phx-value-value`. For example, you have the following options

          [%{label: "Mario", id: "mario", speed: 0}, %{label: "Luigi", id: "luigi", speed: 1}]

    You can set the `phx_value_key` to `:speed` so that `phx-value-value` looks uses the `speed` field of the map as the value
  - placeholder - The placeholder text when no option is selected


  # Example

  ```elixir
    <%= custom_select([%{label: "Mario", id: "mario", speed: 0}, %{label: "Luigi", id: "luigi", speed: 1}],
      "warning",
      phx_value_key: :speed,
      phx_click: "change",
      phx_ref: "speed") %>
  ```

  """
  def custom_select(options, value, opts) do
    phx_ref = Keyword.fetch!(opts, :phx_ref)
    phx_click = Keyword.fetch!(opts, :phx_click)
    phx_value_key = Keyword.get(opts, :phx_value_key, :id)
    placeholder = Keyword.get(opts, :placeholder, "Please select an option")
    selector_icon = Keyword.get(opts, :selector_icon, "icon-solid-selector")

    assigns = %{
      options: options,
      value: value,
      selected_option: Enum.find(options, & Map.get(&1, phx_value_key) == value),
      phx_ref: phx_ref,
      phx_value_key: phx_value_key,
      phx_click: phx_click,
      placeholder: placeholder,
      selector_icon: selector_icon
    }
    ~H"""
    <div x-data="{ show: false }" x-cloak @click.away="show = false">
      <button
        type="button"
        @click="show = !show"
        class="relative w-full pl-3 pr-10 py-2
                border border-gray-300 focus:border-gray-300
              dark:bg-gray-900 dark:border-gray-700
              disabled:bg-gray-200 dark:disabled:bg-gray-700
                focus:ring focus:ring-primary-500/50;
                rounded-md shadow-sm text-left sm:text-sm"
        aria-haspopup="listbox"
        aria-expanded="true">
        <%= if @value && @selected_option do %>
          <span class="flex items-center">
            <%= if icon = Map.get(@selected_option, :icon) do %>
              <%= render_select_icon(icon) %>
            <% end %>
            <span class="ml-3 block truncate"><%= @selected_option.label %></span>
          </span>
        <% else %>
          <p><%= @placeholder %></p>
        <% end %>
        <span class="ml-3 absolute inset-y-0 right-0 flex items-center pr-2">
          <%= Svg.svg_image(@selector_icon, class: "h-5 w-5 text-gray-400") %>
        </span>
      </button>
      <div x-show="show" x-transition>
        <.listgroup
          class="mt-1 w-full bg-white dark:bg-gray-800 ring-1 ring-black dark:ring-white/5
                shadow-lg max-h-56 rounded-md py-1 text-base overflow-auto focus:outline-none sm:text-sm"
          groups={@options}>
          <:parent :let={parent}
            class="hover:bg-gray-100 dark:hover:bg-gray-900 dark:text-white rounded block"
            list_item_class="text-gray-900">
            <div class="relative w-full py-2 px-3 cursor-pointer" phx-click={@phx_click} phx-value-ref={@phx_ref} phx-value-value={parent[@phx_value_key]} @click="show = false">
              <div class="flex items-center">
                <%= if icon = Map.get(parent, :icon) do %>
                  <%= render_select_icon(icon) %>
                <% end %>
                <span class="font-normal ml-3 block truncate"><%= parent.label %></span>
              </div>
            </div>
          </:parent>
        </.listgroup>
      </div>
    </div>
    """
  end
  defp render_select_icon({:svg, name}) do
    assigns = %{name: name}
    ~H"""
    <%= Svg.svg_image(@name, class: "inline h-5 w-5 mr-2") %>
    """
  end
  defp render_select_icon({:external, uri}) do
    assigns = %{uri: uri}
    ~H"""
    <img src={@uri} class="inline h-5 w-5 mr-2" />
    """
  end

  @doc """
  Builds the URL for the monitor image
  """
  def monitor_image_url(monitor_logical_name) do
    "https://assets.metrist.io/monitor-logos/#{monitor_logical_name}.png"
  end

  @doc """
  User for a socket
  """
  def user(socket), do: socket.assigns.current_user

  @doc """
  Account ID for a socket
  """
  def account_id(socket), do: user(socket).account_id

  @doc """
  Extract actor information out of various kinds of objects.
  """

  def actor_of(socket = %Phoenix.LiveView.Socket{}) do
    actor_of(socket.assigns.current_user)
  end

  def actor_of(conn = %Plug.Conn{}) do
    case Plug.Conn.get_session(conn, :current_user) do
      nil ->
        case Plug.Conn.get_session(conn, :metrist_api_token) do
          true ->
            Backend.Auth.Actor.metrist_api_token()
          _ ->
            case Plug.Conn.get_session(conn, :account_api_token) do
              true ->
                Backend.Auth.Actor.api_token(Plug.Conn.get_session(conn, :account_id))
              _ ->
                Backend.Auth.Actor.anonymous()
            end
        end
      user ->
        actor_of(user)
    end
  end

  def actor_of(user = %Backend.Projections.User{}) do
    Backend.Auth.Actor.user(user.id, user.account_id)
  end

  def actor_of(nil) do
    Backend.Auth.Actor.anonymous()
  end

  @doc """
  Dispatch a command to `Backend.App` with standardized metadata obtained
  from whatever can be an actor source (see `actor_of/1` for what can be an
  actor source).
  """
  def dispatch_with_meta(actor_source, command, opts \\ []) do
    actor = actor_of(actor_source)
    Backend.App.dispatch_with_actor(actor, command, opts)
  end

  defdelegate dispatch_with_auth_check(socket, command), to: Backend.Auth.CommandAuthorization

  def formatted_duration(milliseconds) when is_number(milliseconds) and milliseconds > 5000, do: {Timex.Duration.from_milliseconds(milliseconds) |> Timex.Duration.to_seconds(), "s"}
  def formatted_duration(milliseconds) when is_number(milliseconds) and milliseconds <= 5000, do: {milliseconds, "ms"}
  def formatted_duration(milliseconds), do: {milliseconds, "ms"}

  def format_telemetry_value(f, opts \\ []) do
    default_opts = [joiner: " "]
    opts = Keyword.merge(default_opts, opts)

    {number, suffix} = case formatted_duration(f) do
      {n, s} when is_nil(n) ->
        {"…", s}
      {n, s} when is_float(n) ->
        {:erlang.float_to_binary(n, decimals: 2), s}
      {n, s} ->
        {"#{n}.00", s}
    end

    "#{number}#{opts[:joiner]}#{suffix}"
  end

  def get_monitor_display_name(monitors, monitor_logical_name) do
    case Enum.find(monitors, &(&1.logical_name == monitor_logical_name)) do
      nil -> monitor_logical_name
      mon -> mon.name
    end
  end

  def monitor_dropdown_values(monitors, opts \\ []) do
    opts = opts
    |> Keyword.put_new(:include_all_option, true)

    monitor_names = monitors |> Enum.map(fn m -> { m.name, m.logical_name } end)

    if opts[:include_all_option] == true do
      [{"All", "all"} | monitor_names]
    else
      monitor_names
    end
  end

  def subscribe_to_monitors(currently_subscribed_monitors, monitors, account_id_to_subscribe_to, selected_monitors) do
    # unsubscribe from all existing subscriptions
    currently_subscribed_monitors
    |> Enum.each(&Backend.PubSub.unsubscribe/1)

    # subscribe to appropriate monitors based on account_id_to_subscribe_to (SHARED or the user's account)
    monitors
    |> Enum.reduce([], fn m, acc ->
      if Enum.empty?(selected_monitors) or m.logical_name in selected_monitors do
        id = Backend.Projections.construct_monitor_root_aggregate_id(account_id_to_subscribe_to, m.logical_name)
        Logger.debug("Subscribing to Monitor:#{id}")
        Backend.PubSub.subscribe("Monitor:#{id}")
        [ "Monitor:#{id}" | acc ]
      else
        acc
      end
    end)
  end

  def get_monitor_status_color(0), do: "healthy"
  def get_monitor_status_color("up"), do: "healthy"
  def get_monitor_status_color(:up), do: "healthy"
  def get_monitor_status_color(1), do: "degraded"
  def get_monitor_status_color("degraded"), do: "degraded"
  def get_monitor_status_color(:degraded), do: "degraded"
  def get_monitor_status_color(2), do: "down"
  def get_monitor_status_color("down"), do: "down"
  def get_monitor_status_color(:down), do: "down"
  def get_monitor_status_color("issues"), do: "issues"
  def get_monitor_status_color(:issues), do: "issues"
  def get_monitor_status_color("blocked"), do: "gray-bright"
  def get_monitor_status_color(:blocked), do: "gray-bright"

  def get_monitor_status_color(_), do: "black"

  def get_monitor_status_border_class(state) when is_binary(state), do: "border-#{get_monitor_status_color(state)}"
  def get_monitor_status_border_class(state) when is_integer(state), do: "border-#{get_monitor_status_color(state)}"
  def get_monitor_status_border_class(state) when is_atom(state), do: "border-#{get_monitor_status_color(state)}"
  def get_monitor_status_border_class(detail) when is_map(detail), do: "border-#{get_monitor_status_color(detail.state)}"
  def get_monitor_status_border_class(detail) when is_nil(detail), do: "border-#{get_monitor_status_color(nil)}"

  def datetime_to_tz(time, nil), do: datetime_to_tz(time, "Etc/UTC")
  def datetime_to_tz(time, tz) do
    utc_dt = DateTime.from_naive!(time, "Etc/UTC")
    resolved_tz = Timex.Timezone.get(tz, Timex.now)
    Timex.Timezone.convert(utc_dt, resolved_tz)
  end

  @spec format_with_tz(NaiveDateTime.t(), String.t() | nil) :: String.t()
  def format_with_tz(time, tz) when is_binary(tz) do
   converted_dt = datetime_to_tz(time, tz)
   zone_abbr = Timex.format!(converted_dt, "{Zabbr}")
   Timex.format!(converted_dt, "%d %b, %H:%M:%S ", :strftime) <> zone_abbr
  end
  def format_with_tz(time, nil), do: format_with_tz(time, "Etc/UTC")

  def get_up_to_date_user(user) do
    if is_user_up_to_date?(user) do
      {:ok, user}
    else
      {:updated, Backend.Projections.User.get_user!(user.id)}
    end
  end

  def is_user_up_to_date?(nil), do: true
  def is_user_up_to_date?(user) do
    keys_from_user = Map.keys(user) |> Enum.sort()
    keys_from_projections = Map.keys(%Backend.Projections.User{}) |> Enum.sort()
    keys_from_user === keys_from_projections
  end

  def get_account_name_with_id(account) do
    account_name =  Backend.Projections.Account.get_account_name(account)

    "#{account_name} (#{account.id})"
  end

  def get_status_page_data(monitor_logical_name, filter_components) do
    Backend.Projections.Dbpa.StatusPage.status_pages_changes_for_active_incident(
      "SHARED",
      monitor_logical_name,
      filter_components
    )
    |> Enum.group_by(& &1.component_name)
    |> Enum.map(fn {_component, changes} ->
      sorted_changes = Enum.sort_by(changes, & &1.changed_at, {:desc, NaiveDateTime})

      [newest | _rest] = sorted_changes
      [oldest | _rest] = Enum.reverse(sorted_changes)

      {newest.state, oldest.changed_at}
    end)
    |> Enum.reduce({:up, NaiveDateTime.utc_now()}, fn {curr_state, curr_time},
                                                      {acc_state, acc_time} ->
      state = Backend.Projections.Dbpa.Snapshot.get_worst_state(acc_state, curr_state)
      time = if Timex.before?(curr_time, acc_time), do: curr_time, else: acc_time

      {state, time}
    end)
  end

  def status_page_state_from_snapshot(snapshot) do
    List.foldl(snapshot.status_page_component_check_details, :up, fn x, acc ->
      Backend.Projections.Dbpa.Snapshot.get_worst_state(x.state, acc)
    end)
  end

  def status_page_only_monitor?(account_id, monitor_logical_name) do
    has_status_page_data_only =
      if monitor_logical_name do
        case Backend.RealTimeAnalytics.get_snapshot(account_id, monitor_logical_name) do
          {:error, _} -> false
          {:ok, snapshot} -> snapshot.check_details == []
        end
      else
        false
      end
    has_status_page_data_only
  end

  def snapshot_state(nil), do: nil
  def snapshot_state(snapshot), do: snapshot.state

  def get_provider_icon_for_monitor(monitor_logical_name) do
    tags =
      case Backend.Projections.Dbpa.MonitorTags.get_tags_for_monitor(monitor_logical_name) do
        %{tags: tags} -> tags
        _ -> []
      end

    MapSet.new(tags)
    |> MapSet.intersection(MapSet.new(["aws", "azure", "gcp"]))
    |> MapSet.to_list()
    |> List.first()
    |> case do
      "aws" -> {:svg, "aws-icon"}
      "azure" -> {:svg, "azure-icon"}
      "gcp" -> {:svg, "gcp-icon"}
      _ -> {:png, monitor_logical_name}
    end
  end
end
