defmodule BackendWeb.Admin.Component.FreeTrialConfigureComponent do
  use BackendWeb, :live_component

  @impl true
  def handle_event("extend-trial", %{"days" => days}, socket) do
    days = String.to_integer(days)

    cmd = %Domain.Account.Commands.UpdateFreeTrial{
      id: socket.assigns.account.id,
      free_trial_end_time:
        extend_trial_time(
          socket.assigns.account.free_trial_end_time,
          NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          days
        )
    }

    :ok = Backend.App.dispatch(cmd)

    send(self(), "close_modal")

    {:noreply, socket
      |> put_flash(:info, "Free trial successfully updated for account #{socket.assigns.account.id}")}
  end

  def handle_event("end-trial", _params, socket) do
    cmd = %Domain.Account.Commands.UpdateFreeTrial{
      id: socket.assigns.account.id,
      free_trial_end_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
    :ok = Backend.App.dispatch(cmd)

    send(self(), "close_modal")

    {:noreply, socket
      |> put_flash(:info, "Free trial ended for account #{socket.assigns.account.id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <p>Account ID: <%= @account.id %></p>
      <%= if @account.free_trial_end_time do %>
        <p class="pb-4">Free trial expires at: <%= NaiveDateTime.to_iso8601(@account.free_trial_end_time)%></p>
      <% else %>
        <p class="pb-4">No free trial active</p>
      <% end %>
      <h3>Actions</h3>
      <ul>
        <li class="pb-2">
          <button phx-target={@myself}
            phx-click="extend-trial"
            phx-value-days="30"
            data-confirm={"Do you wish to extend Account ID: #{@account.id} free trial for 30 days?"}
            class="btn btn-green">Extend for 30 days</button>
        </li>
        <li class="pb-2">
          <button phx-target={@myself}
            phx-click="end-trial"
            data-confirm={"Do you wish to end Account ID: #{@account.id} free trial?"}
            class="btn btn-red">End free trial</button>
        </li>
      </ul>
    </div>
    """
  end

  defp extend_trial_time(current, now, shift_days_amount) do
    if current do
      Enum.max([now, current], Date)
    else
      now
    end
    |> Timex.shift(days: shift_days_amount)
  end

end
