defmodule BackendWeb.Components.MonitorStateBadge do
  use BackendWeb, :component

  @snapshot_up :up
  @snapshot_degraded :degraded
  @snapshot_issues :issues
  @snapshot_down :down

  def render(assigns) do
    assigns = assigns
    |> assign_new(:background_class, fn -> "bg-#{BackendWeb.Helpers.get_monitor_status_color(assigns.state)}" end)
    |> assign_new(:class, fn -> "" end)
    |> assign_new(:icon_only, fn -> false end)
    |> assign_new(:show_icon, fn -> true end)
    |> assign_new(:badge_font_class, fn -> "font-black" end)

    ~H"""
    <%= if assigns.state do %>
    <div
      class={"inline-block rounded text-white text-sm uppercase #{assigns.class} #{@background_class}"}>
      <%= if assigns.show_icon do %><%= health_emoji(assigns.state) %><% end %><%= if !assigns.icon_only do %> <span class={"#{@badge_font_class}"}><%= health_state(assigns.state) %></span><% end %>
      </div>
    <% end %>
    """
  end

  defp health_state(@snapshot_up), do: "Healthy"
  defp health_state(@snapshot_degraded), do: "Degraded"
  defp health_state(@snapshot_issues), do: "Partially Down"
  defp health_state(@snapshot_down), do: "Down"

  # C# can send integers instead of symbolic enums. Support that
  defp health_state(0), do: health_state(@snapshot_up)
  defp health_state(1), do: health_state(@snapshot_degraded)
  defp health_state(2), do: health_state(@snapshot_down)

  defp health_state(_), do: "Unknown"

  defp health_emoji(@snapshot_up), do: "🎉"
  defp health_emoji(@snapshot_degraded), do: "⚠️️"
  defp health_emoji(@snapshot_issues), do: "💥"
  defp health_emoji(@snapshot_down), do: "🛑"

  # C# can send integers instead of symbolic enums. Support that
  defp health_emoji(0), do: health_emoji(@snapshot_up)
  defp health_emoji(1), do: health_emoji(@snapshot_degraded)
  defp health_emoji(2), do: health_emoji(@snapshot_down)
end
