defmodule BackendWeb.Components.Breadcrumb do
  @moduledoc """
  Navigation assistance a.k.a. "breadcrumbs"

  Historically, breadcrumbs corresponded with browser history; these days, it is
  more common to see a static hierarchical context (and calling them 'breadcrumbs'
  just because they often look the same can be confusing but that's how terms evolve).

  Our breadcrumbs are clearly "context", no bearing at all on browser history,
  how the user got here, and so on. They need to be a path representation of where
  in our menu hierarchy a page lives, IOW the static context of a page, not the dynamic
  "how did we get here?".

  This component is pulled in through our main layout. You can assign two settings:

  * _breadcrumb_items_ is forwarded here as `items` and can be used to explicitly
    set the items displayed. It needs to be a list of `{name, path}` tuples.
  * _hide_breadcrumb_ is forwarded here as `hidden` and can be used to completely
    suppress the display.
  """
  use BackendWeb, :live_component

  @type breadcrumb_item_name :: String.t()
  @type breadcrumb_item_path :: String.t()
  @type assigns :: %{
    items: [{breadcrumb_item_name(), breadcrumb_item_path()}] | nil,
    path: String.t,
    hidden: boolean()
  }

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  @spec update(assigns(), Phoenix.LiveView.Socket.t) :: {:ok, Phoenix.LiveView.Socket.t}
  def update(assigns=%{items: nil}, socket) do
    {:ok, assign(socket, items: breadcrumb_items(assigns.path), hidden: assigns.hidden)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, items: assigns.items, hidden: assigns.hidden)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="capitalize text-sm">
      <%= unless @hidden do %>
        <%= for {{name, path}, i} <- Enum.with_index(@items) do %>
          <%= if i < Enum.count(@items) - 1 do %>
            <.link navigate={path} class="mr-1 text-muted">
              <%= name %>
            </.link>
            <%= svg_image("chevron-down", class: "inline -rotate-90 h-2 w-2 -mt-0.5") %>
          <% else %>
            <%= name %>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp breadcrumb_items(path) when is_binary(path) do
    {items, _} = path
      |> String.split("/", trim: true)
      |> Enum.map_reduce("", fn element, acc ->
        curr_path = "#{acc}/#{element}"
        name = curr_path
        |> maybe_sub_monitor_name(element)

        {{name, curr_path}, curr_path}
      end)

    items
    # A bit of a hack: monitor check pages will point at a non-existing "checks" page
    |> Enum.reject(fn
      {"checks", _} -> true
      _ -> false
    end)
  end

  # Through these heuristics, we're trying to make sure that most pages do not
  # explicitly need to set their breadcrumbs. If that doesn't work, pick your poison:
  # extend these heuristics or explicitly override

  defp maybe_sub_monitor_name(<<"/monitors/",logical_name::binary>>, logical_name) do
    case Backend.Projections.get_monitor(Domain.Helpers.shared_account_id, logical_name) do
      %{name: name} -> name
      _ -> logical_name
    end
  end
  defp maybe_sub_monitor_name(_path, logical_name), do: logical_name
end
