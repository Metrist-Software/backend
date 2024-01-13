defmodule BackendWeb.Admin.AdminLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Admin Tools")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Admin Tools</h2>
        <ul class="list-none">
          <%= for page <- get_admin_utility_pages() do %>
            <li class="my-2">
              <.link navigate={Routes.live_path(@socket, page)} class="link">
                <%= friendly_name(page) %>
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    """
  end

  def get_admin_utility_pages() do
    with {:ok, list} <- :application.get_key(:backend, :modules) do
      list
      |> Enum.filter(&is_admin_utility_page?/1)
    end
  end

  def is_admin_utility_page?(m) do
    m
    |> Module.split
    |> fn(m) -> match?(["BackendWeb", "Admin", "Utilities" | _], m) end.()
  end

  def friendly_name (page) do
    name = page
    |> Module.split
    |> List.last
    |> String.replace_trailing("Live", "")

    Regex.replace(~r/([a-z])([A-Z])/, name, "\\1 \\2")
  end
end
