defmodule BackendWeb.Components.ListGroupSelect do
  use BackendWeb, :live_component

  @impl true
  def mount(socket) do
    socket = assign(socket,
      list_group_data: [],
      include_search: false,
      filter_term: "",
      search: {}
    )
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = socket
    |> assign(
      list_group_data: assigns.list_group_data,
      include_search: assigns.include_search,
      button_class: Map.get(assigns, :button_class, "")
    )

    socket = case Map.get(assigns, :initial) do
      nil -> socket
      {} -> socket
      initial -> assign(socket, search: initial)
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="[&_button]:md:w-max [&_button]:w-full">
      <.dropdown menu_items_wrapper_class="w-full md:w-max" class="w-full">
        <:trigger_element>
          <div class="inline-flex justify-center w-full px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm dark:text-gray-300 dark:bg-gray-900 dark:hover:bg-gray-800 dark:focus:bg-gray-800 hover:bg-gray-50 focus:outline-none">
            <%= render_filter_label(@search, @list_group_data) %>
            <%= maybe_render_clear_filter(@search, @myself) %>
            <Heroicons.chevron_down solid class="w-5 h-5 ml-2 -mr-1 dark:text-gray-100 inline" />
          </div>
        </:trigger_element>

        <%= if false and @include_search do %>
          <form phx-change="filter" phx-submit="filter" phx-target={@myself} class="px-3">
            <div class="relative text-gray-600 focus-within:text-gray-400">
              <span class="absolute inset-y-0 left-0 flex items-center pl-2">
                <div class="p-1 focus:outline-none focus:shadow-outline">
                  <%= BackendWeb.Helpers.Svg.svg_image("icon-filter", class: "h-3 w-3") %>
                </div>
              </span>
              <input
                type="search"
                name="input-term"
                class="!pl-7 bg-gray-100 focus:bg-white focus:text-gray-900 dark:focus:text-white"
                placeholder="Filter by"
                autocomplete="off"
              >
            </div>
          </form>
        <% end %>

        <.listgroup groups={filter_groups(@list_group_data, @filter_term)} role="menu" class="mt-2 pl-3 max-h-64 overflow-y-auto">
          <:parent :let={parent} class="hover:bg-gray-100 dark:hover:bg-gray-900 rounded block p-1" role="menuitem">
            <div
              class="font-bold inline-block w-full cursor-pointer"
              phx-click="select-parent"
              phx-value-id={parent.id}
              phx-target={@myself}
              @click="show=false"
            >
              <%= parent.label %>
            </div>
          </:parent>

          <:child :let={child} class="hover:bg-gray-100 dark:hover:bg-gray-900 rounded" role="menuitem">
            <div
              class="text-sm p-1 pl-3 cursor-pointer w-full"
              phx-click="select-child"
              phx-value-id={child.id}
              phx-target={@myself}
              @click="show=false"
            >
              <%= child.label %>
            </div>
          </:child>
        </.listgroup>
      </.dropdown>
    </div>
    """
  end

  @impl true
  def handle_event("filter", %{"input-term" => term}, socket) do
    {:noreply, assign(socket, filter_term: term)}
  end

  def handle_event("select-parent", %{"id" => id}, socket) do
    children = Enum.find(socket.assigns.list_group_data, & &1.id == id)
    |> Map.get(:children, [])

    send(self(), {:list_group_parent_selected, id, children})

    {:noreply, assign(socket, search: {:parent, id})}
  end

  def handle_event("select-child", %{"id" => id}, socket) do
    send(self(), {:list_group_child_selected, id})

    {:noreply, assign(socket, search: {:child, id})}
  end

  def handle_event("clear", _, socket) do
    send(self(), :list_group_select_cleared)

    {:noreply, assign(socket, search: {})}
  end

  def filter_groups(list, filter_term) do
    filter_fn = & String.contains?(String.downcase(&1.label), String.downcase(filter_term))

    groups = Enum.filter(list, filter_fn)
              |> Enum.into(%{}, & {&1.id, %{&1 | children: []}})
    children = Enum.filter(list, fn item -> Enum.any?(item.children, filter_fn) end)
              |> Enum.into(%{}, & {&1.id, %{&1 | children: Enum.filter(&1.children, filter_fn)}})

    Map.merge(groups, children) |> Map.values()
  end

  defp render_filter_label({:child, id}, options) do
    child = Enum.find_value(options, fn group ->
      Enum.find(group.children, & &1.id == id)
    end)

    label = case child do
      %{label: label} -> label
      nil -> ""
    end

    assigns = %{label: label}
    ~H"""
    Filter by:&nbsp;<span class="font-bold"><%= @label %></span>
    """
  end
  defp render_filter_label({:parent, id}, options) do
    parent = Enum.find(options, & &1.id == id)

    label = case parent do
      %{label: label} -> label
      nil -> ""
    end

    assigns = %{label: label}
    ~H"""
    Filter by: <span class="font-bold"><%= @label %></span>
    """
  end
  defp render_filter_label(_, _) do
    assigns = %{}
    ~H"Filter by"
  end

  def maybe_render_clear_filter(search, myself, svg_attrs \\ [])
  def maybe_render_clear_filter({}, _myself, _svg_attrs) do
    assigns = %{}
    ~H""
  end
  def maybe_render_clear_filter(_, myself, svg_attrs) do
    assigns = %{myself: myself, svg_attrs: svg_attrs}
    ~H"""
      <a id="$id('clear-filter')" href="#" phx-hook="ClickStopPropagation" phx-value-event="clear" phx-value-target={@myself}>
        <%= svg_image("icon-x", class: "w-3 h-3 ml-1 pb-0.5 inline-block z-10 #{@svg_attrs}") %>
      </a>
    """
  end
end
