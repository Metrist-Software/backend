defmodule BackendWeb.Components.NoticeEditor do
  use BackendWeb, :live_component
  alias Backend.Projections.Notice

  def mount(socket) do
    # Set some defaults, this happens before the assigns are processed
    socket = assign(socket,
      notice: nil,
      monitor_options: [], # TODO: Populate monitors to allow putting on non-monitor specific pages
      show_monitor_select: false,
      include_end_date: true,
      show_preview_button: false
    )
    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = socket
    |> assign(assigns)
    |> assign(id: assigns.id,
              include_end_date: !is_nil(assigns.notice.end_date),
              show_preview_button: assigns[:show_preview_button] || false)

    {:ok, socket}
  end

  def handle_event("submit", _params, socket) do
    if is_nil(socket.assigns.notice.id) do
      cmd = %Domain.Notice.Commands.Create{
        id: Domain.Id.new(),
        monitor_id: socket.assigns.notice.monitor_id,
        summary: socket.assigns.notice.summary,
        description: socket.assigns.notice.description,
        end_date: if(socket.assigns.include_end_date, do: socket.assigns.notice.end_date, else: nil)
      }
      Backend.App.dispatch(cmd)

      send(self(), {:notice_created, %Notice{socket.assigns.notice | id: cmd.id, end_date: cmd.end_date}})
    else
      cmd = %Domain.Notice.Commands.Update{
        id: socket.assigns.notice.id,
        summary: socket.assigns.notice.summary,
        description: socket.assigns.notice.description,
        end_date: if(socket.assigns.include_end_date, do: socket.assigns.notice.end_date, else: nil)
      }
      Backend.App.dispatch(cmd)

      send(self(), {:notice_updated, %Notice{socket.assigns.notice | end_date: cmd.end_date}})
    end

    {:noreply, assign(socket, notice: %Notice{})}
  end

  def handle_event("change", params=%{"_target" => ["include-end-date"]}, socket) do
    {:noreply, assign(socket, include_end_date: Map.has_key?(params, "include-end-date"))}
  end

  def handle_event("change", %{"_target" => ["end-date"], "end-date" => end_date}, socket) do
    {:noreply, assign(socket,
        notice: Map.put(socket.assigns.notice, :end_date, Timex.parse!(end_date, "%Y-%m-%dT%H:%M", :strftime))
    )}
  end

  def handle_event("change", params=%{"_target" => [target]}, socket) do
    {:noreply, assign(socket, notice: Map.put(socket.assigns.notice, String.to_existing_atom(target), Map.get(params, target)))}
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:notice_edit_canceled, socket.assigns.id})
    {:noreply, socket}
  end

  def handle_event("preview", _params, socket) do
    send(self(), {:notice_previewed, socket.assigns.notice})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="my-5 py-3 px-4 rounded dark:bg-gray-shade bg-gray-bright">
      <form phx-submit="submit" phx-change="change" phx-target={@myself}>
        <%= if @show_monitor_select do %>
        <label for={"#{@id}-monitor_id"} class="form-label">
          Subscription Type
        </label>
        <select id={"#{@id}-monitor_id"} name="monitor_id">
          <%= options_for_select(@monitor_options, @monitor_id) %>
        </select>
        <% end %>

        <label for={"#{@id}-summary"} class="form-label mt-3">
          Summary
        </label>
        <input id={"#{@id}-summary"} name="summary" type="text" class="text-input" value={@notice.summary} required />

        <label for={"#{@id}-description"} class="form-label mt-3">
          Description
        </label>
        <textarea id={"#{@id}-description"} name="description" class="text-input" rows="5"><%= @notice.description %></textarea>

        <label for={"#{@id}-include-end-date"} class="form-label mt-3">
          <input
            id={"#{@id}-include-end-date"}
            name="include-end-date"
            type="checkbox"
            class="mr-3"
            checked={@include_end_date}
          />
          Include notice end date?
        </label>

        <%= if @include_end_date do %>
        <label for={"#{@id}-end-date"} class="form-label mt-3">
          End Date (UTC)
        </label>

        <input
          type="datetime-local"
          id={"#{@id}-end-date"}
          name="end-date"
          value={Timex.now() |> Timex.format!("%Y-%m-%dT%H:%M", :strftime)}
          min={Timex.now() |> Timex.format!("%Y-%m-%dT%H:%M", :strftime)}
        >
        <% end %>

        <button type="submit" class="mt-3 btn btn-green">
          Submit
        </button>

        <button type="button" class="mt-3 btn btn-blue btn-outline" phx-click="cancel" phx-target={@myself}>
          Cancel
        </button>

        <%= if @show_preview_button do %>
          <button type="button" class="mt-3 btn btn-blue btn-outline" phx-click="preview" phx-target={@myself}>
            Preview
          </button>
        <% end %>
      </form>
    </div>
    """
  end
end
