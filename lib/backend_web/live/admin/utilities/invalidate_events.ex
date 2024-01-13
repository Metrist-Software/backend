defmodule BackendWeb.Admin.InvalidateEventsForm do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :start_time, :naive_datetime
    field :end_time, :naive_datetime
    field :check
  end

  def changeset(form, params \\ %{}) do
    cast(form, params, [:check, :start_time, :end_time])
    |> validate_required([:check, :start_time, :end_time])
    |> validate_datetime
  end

  defp validate_datetime(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)
    do_validate_datetime(changeset, start_time, end_time)
  end

  defp do_validate_datetime(changeset, %NaiveDateTime{} = start_dt, %NaiveDateTime{} = end_dt) do
    if NaiveDateTime.compare(start_dt, end_dt) == :gt do
      add_error(changeset, :start_time, "Cannot be later than end time")
    else
      changeset
    end
  end

  defp do_validate_datetime(changeset, _start, _end) do
    changeset
  end
end

defmodule BackendWeb.Admin.Utilities.InvalidateEvents do
  use BackendWeb, :live_view

  alias BackendWeb.Admin.InvalidateEventsForm

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    monitors = Backend.Projections.list_monitors("SHARED")
    [first_monitor | _] = monitors
    checks = get_checks(first_monitor.logical_name)

    socket =
      assign(
        socket,
        page_title: "Invalidate Events",
        monitors: monitors,
        monitor: first_monitor.logical_name,
        checks: checks,
        changeset:
          %InvalidateEventsForm{}
          |> InvalidateEventsForm.changeset(%{
            check: get_selected_check(checks)
          })
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Invalidate events</h2>
        <p class="m-5">This invalidates events for a time range across ALL accounts</p>

        <.form :let={f} as={:form} for={@changeset} phx-change="validate" phx-submit="invalidate_events">
          Monitor
          <select id="monitor" name="monitor" phx-click="select-monitor" value={@monitor} required>
            <%= options_for_select(BackendWeb.Helpers.monitor_dropdown_values(@monitors, include_all_option: false), @monitor) %>
          </select>

          <%= if length(@checks) > 0 do %>
            Check

            <div>
              <%= select(f, :check, Enum.map(@checks, fn c -> { c.name || c.logical_name, c.logical_name } end)) %>
            </div>

            <div>
              <%= label f, :start_time, "Start time (UTC)" %>
              <%= datetime_local_input f, :start_time %>
              <%= error_tag f, :start_time %>
            </div>

            <div>
              <%= label f, :end_time, "End time (UTC)" %>
              <%= datetime_local_input f, :end_time %>
              <%= error_tag f, :end_time %>
            </div>

            <button
                data-confirm="Are you sure you want to invalidate events?"
                disabled={!@changeset.valid?} 
                type="submit"
                class={"#{button_class()} mt-3"} 
                phx-disable-with="Loading...">
              Invalidate Events
            </button>
            <% else %>
              No checks found.
          <% end %>
        </.form>
      </div>
    """
  end

  defp get_selected_check([]), do: nil
  defp get_selected_check([check | _]), do: check.logical_name

  @impl true
  def handle_event("validate", params, socket) do
    IO.inspect(params)

    changeset =
      %InvalidateEventsForm{}
      |> InvalidateEventsForm.changeset(params["form"] || %{})
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("select-monitor", %{"value" => monitor}, socket) do
    checks = get_checks(monitor)

    {
      :noreply,
      assign(socket,
        monitor: monitor,
        checks: checks,
        changeset:
          %InvalidateEventsForm{}
          |> InvalidateEventsForm.changeset(%{
            check: get_selected_check(checks)
          })
      )
    }
  end

  def handle_event("invalidate_events", params, socket) do
    %{monitor: monitor_logical_name} = socket.assigns

    form =
      InvalidateEventsForm.changeset(%InvalidateEventsForm{}, params["form"])
      |> Ecto.Changeset.apply_action!(:validate)

    for account <-
          Backend.Projections.get_accounts_for_monitor(monitor_logical_name,
            list_accounts_opts: [type: nil]
          ),
        id =
          Backend.Projections.construct_monitor_root_aggregate_id(
            account.id,
            monitor_logical_name
          ),
        cmd <- [
          %Domain.Monitor.Commands.InvalidateEvents{
            id: id,
            logical_name: monitor_logical_name,
            start_time: form.start_time,
            end_time: form.end_time,
            check_logical_name: form.check,
            account_id: account.id
          },
          %Domain.Monitor.Commands.InvalidateErrors{
            id: id,
            logical_name: monitor_logical_name,
            start_time: form.start_time,
            end_time: form.end_time,
            check_logical_name: form.check,
            account_id: account.id
          }
        ] do
      BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)
    end

    {
      :noreply,
      socket
      |> clear_flash()
      |> put_flash(:info, "Succesfully invalidated events on #{monitor_logical_name}")
    }
  end

  defp get_checks(monitor) do
    Backend.Projections.get_checks("SHARED", monitor) |> Enum.sort_by(& &1.name)
  end
end
