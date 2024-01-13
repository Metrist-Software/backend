defmodule BackendWeb.Components.Monitor.MonitorCheck do
  use BackendWeb, :live_component

  def mount(socket) do
    socket = assign(socket,
      check: nil,
      account_id: nil,
      monitor: nil,
      snapshot: nil,
      telemetry: nil,
      instances: [],
      description: nil,
      vendor_link: nil
    )
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok,
    socket
    |> assign(assigns)
    |> assign_proper_instances()
    |> assign_description_and_link()
    }
  end

  defp assign_description_and_link(%{assigns: %{ monitor: monitor, check: check }} = socket) do
    description = String.trim(Backend.Docs.Generated.Checks.description(monitor.logical_name, check.logical_name))
    link = String.trim(Backend.Docs.Generated.Checks.docs_url(monitor.logical_name, check.logical_name))

    socket
    |> assign(:description, description)
    |> assign(:vendor_link, link)
  end

  defp assign_proper_instances(%{assigns: %{instances: instances, snapshot: snapshot, check: check}} = socket) do
    updated_instances =
      instances
      |> Enum.filter(&(Enum.any?(snapshot.check_details, fn cd -> cd.instance == &1 && check.logical_name == cd.check_id end)))

    socket
    |> assign(:instances, updated_instances)
  end

  # we will have multiple of these on a page so preload data all at once
  def preload(list_of_assigns) do
    first_data = Enum.at(list_of_assigns, 0, nil)

    # load all account telemetry for 12 hours
    from_time = DateTime.add(DateTime.utc_now(), :timer.hours(12) * -1, :millisecond)
      |> round_to_5_min

    telemetry = Backend.Telemetry.get_aggregate_telemetry(from_time, "10 minutes", first_data.monitor.logical_name, :p50, group_by_instance: true, account_id: first_data.account_id, gap_fill: true)
    Enum.map(list_of_assigns, fn assigns ->
      assigns
      |> Map.put(:telemetry, Enum.filter(telemetry, &(&1.check_id == assigns.check.logical_name)))
    end)
  end

  defp maybe_link(assigns) do
    if assigns.show_link_to_check_details? do
      ~H"""
      <.link navigate={@href}>
        <%= render_slot(@inner_block) %>
      </.link>
      """
    else
      ~H"""
      <div>
        <%= render_slot(@inner_block) %>
      </div>
      """
    end
  end

  # Since we have no descriptions for most monitors we want to eliminate the
  # grid row height in that case. Team has been told to make sure every check on a monitor has a
  # description with links, description without link, or none so that boxes don't misalign
  def get_grid_heights_for_description_and_link("", ""), do: "grid-template-rows: 2rem 0rem 0rem auto"
  def get_grid_heights_for_description_and_link("", _), do: "grid-template-rows: 2rem 0rem 1rem auto"
  def get_grid_heights_for_description_and_link(_, ""), do: "grid-template-rows: 2rem 2rem 0rem auto"
  def get_grid_heights_for_description_and_link(_description, _vendor_link), do: "grid-template-rows: 2rem 2rem 1rem auto"

  # Round to nearest 5. I.e. (10:48pm --> 10:45pm)
  defp round_to_5_min(curr_date = %DateTime{ minute: min }) do
    nearest_5 = 10 * div(min, 10) + 5
    curr_date |> DateTime.add((nearest_5 - min) * 60, :second)
  end
end
