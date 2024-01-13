defmodule BackendWeb.Components.StatusPage.UI.PageComponent do
  @moduledoc """
  Utility module for mapping various states to CSS properties needed by the status page component UI
  """
  @state_up :up
  @state_degraded :degraded
  @state_issues :issues
  @state_down :down
  @state_maintenance :maintenance
  @state_blocked :blocked

  def class(%{type: :spinner, state: state})
      when state in [
             @state_up,
             @state_degraded,
             @state_issues,
             @state_down,
             @state_maintenance,
             @state_blocked
           ],
      do: "text-#{state_to_css(state)}"

  def class(_), do: "text-healthy"

  defp state_to_css(:up), do: "healthy"
  defp state_to_css(:down), do: "down"
  defp state_to_css(:issues), do: "issues"
  defp state_to_css(:degraded), do: "degraded"
  defp state_to_css(:blocked), do: "blocked"
  defp state_to_css(:maintenance), do: "blue-shade"
end
