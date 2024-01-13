defmodule BackendWeb.Components.Monitor.MonitorInstance do
  use BackendWeb, :component

  def render(assigns) do
    assigns = assign_check_details(assigns)

    ~H"""
    <div class="flex flex-row mt-5 items-center">
      <div class={"flex flex-col border-l-8 rounded pl-2 py-2 #{BackendWeb.Helpers.get_monitor_status_border_class(@details)}"}>
        <.details_description details={@details} />
      </div>
      <div class="spark flex-1 ml-2 mr-2">
        <div class="spark_graph w-full">
          <%= get_graph_for_instance(@telemetry, @instance) %>
          <span class="text-xs">Last 12h from <span class="pill mr-2 inline-block"><%= @instance %></span></span>
        </div>
      </div>
    </div>
    """
  end

  defp details_description(%{details: details} = assigns) when details.state == :blocked do
    ~H"""
      <div class="text-lg font-bold">Blocked</div>
      <div class="text-sm"><%= BackendWeb.Helpers.format_telemetry_value(@details.average, joiner: "&nbsp;") |> raw %> Avg</div>
    """
  end

  defp details_description(%{details: details} = assigns) when not is_nil(details) do
    ~H"""
      <div class="text-lg font-bold"><%= BackendWeb.Helpers.format_telemetry_value(@details.current, joiner: "&nbsp;") |> raw %></div>
      <div class="text-sm"><%= BackendWeb.Helpers.format_telemetry_value(@details.average, joiner: "&nbsp;") |> raw %> Avg</div>
    """
  end

  defp details_description(assigns) do
    ~H"""
      <div class="text-lg font-bold">N/A</div>
      <div class="text-sm">N/A Avg</div>
    """
  end

  defp assign_check_details(%{instance: instance, snapshot: snapshot, shared_snapshot: shared_snapshot, check_logical_name: check_logical_name} = assigns) do
    detail = snapshot.check_details
    |> Enum.find(&(&1.instance == instance && &1.check_id == check_logical_name))

    detail = if !detail && shared_snapshot do
      shared_snapshot.check_details
      |> Enum.find(&(&1.instance == instance && &1.check_id == check_logical_name))
    else
      detail
    end

    assigns
    |> assign(:details, detail)
  end

  defp get_graph_for_instance(telemetry, instance) do
    dataset = telemetry
    |> Enum.filter(&(&1.instance_id == instance))
    |> Enum.map(&(&1.value))

    dataset = case length(dataset) do
      0 -> [0]
      _ -> dataset
    end

    dataset
    |> Contex.Sparkline.new()
    |> Map.put(:width, "100%")
    |> Map.put(:height, 20)
    |> Contex.Sparkline.colours("#D3D3D3", "#677389")
    |> Contex.Sparkline.draw()
  end
end
