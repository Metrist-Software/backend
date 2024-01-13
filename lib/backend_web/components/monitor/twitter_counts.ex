defmodule BackendWeb.Components.Monitor.TwitterCounts do
  use BackendWeb, :live_component

  alias Backend.Projections.Dbpa.MonitorTwitterInfo

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    hashtags =
      case MonitorTwitterInfo.get(assigns.monitor_logical_name) do
        nil -> []
        info -> info.hashtags
      end

    counts =
      for hashtag <- hashtags do
        values = Backend.Twitter.counts(assigns.monitor_logical_name, hashtag)
        total =
          values
          |> Enum.map(fn {_t, v} -> v end)
          |> Enum.sum()
        {hashtag, total, Backend.Twitter.counts(assigns.monitor_logical_name, hashtag)}
      end

    total_count =
      counts
      |> Enum.map(fn {_tag, total, _values} -> total end)
      |> Enum.sum()

    socket =
      socket
      |> assign(assigns)
      |> assign(counts: counts)
      |> assign(total_count: total_count)

    {:ok, socket}
  end

  def render(assigns = %{counts: counts}) when counts == [], do: ~H"<div></div>"
  def render(assigns) do
    ~H"""
    <div class="flex flex-row mt-1">
      <div class="flex-grow"></div>
      <%= svg_image("twitter-icon", class: "w-4 h-4 mt-1 inline fill-current") %>
      <div class="ml-2 mr-4">
        <b><%= @total_count %> tweets</b> (last 24h):
      </div>
      <div class="flex flex-col md:flex-row">
      <%= for {tag, total, values} <- @counts do %>
        <div class="mx-2 flex flex-row">
          #<a class="underline" href={"https://twitter.com/hashtag/#{tag}"} target="twitter"><%= tag %></a>&nbsp;
          <div class="text-gray-400">
            (<%= total %>)
          </div>
          <%= if total > 0 do %>
            <div class="mx-1">
              <%= graph(values) %>
            </div>
          <% end %>
        </div>
      <% end %>
      </div>
    </div>
    """
  end

  def graph(values) do
    # For now, we assume that we have all the values there and in order. This should
    # only become an issue if Twitter is every down or for very newly monitored tags.

    # Smooth the values a bit. This graph is not an illustration in a science paper,
    # but a visual trend indicator.
    {l, vs} =
      values
      |> Enum.map(fn {_t, v} -> v end)
      |> Enum.reduce({0, []}, fn x, {v, vs} -> {x, [(v + x) / 2 | vs]} end)

    [l | vs]
    |> Enum.reverse()
    |> Contex.Sparkline.new()
    |> Map.put(:width, 40)
    |> Map.put(:height, 20)
    |> Contex.Sparkline.colours("rgba(0, 0, 0, 0)", "#677389")
    |> Contex.Sparkline.draw()
  end
end
