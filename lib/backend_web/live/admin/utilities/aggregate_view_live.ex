defmodule BackendWeb.Admin.Utilities.AggregateViewLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, state: "", aggregate_type: "monitor")}
  end

  @impl true
  def handle_event("change", %{"aggregate-type" => aggregate_type}, socket) do
    {:noreply, assign(socket, aggregate_type: aggregate_type)}
  end

  def handle_event("submit", %{"aggregate-type" => "monitor", "account" => account, "aggregate" => aggregate}, socket) do
    {:ok, state} = Backend.App.dispatch(
      %Domain.Monitor.Commands.Print{
        id: Backend.Projections.construct_monitor_root_aggregate_id(account, aggregate),
        account_id: account,
        monitor_logical_name: aggregate,
      },
      returning: :aggregate_state
    )

    {:noreply, assign(socket, state: format(state))}
  end

  def handle_event("submit", %{"aggregate-type" => "account", "aggregate" => aggregate}, socket) do
    {:ok, state} = Backend.App.dispatch(
      %Domain.Account.Commands.Print{
        id: aggregate
      },
      returning: :aggregate_state
    )

    {:noreply, assign(socket, state: format(state))}
  end

  def handle_event("submit", %{"aggregate-type" => "user", "aggregate" => aggregate}, socket) do
    {:ok, state} = Backend.App.dispatch(
      %Domain.User.Commands.Print{
        id: aggregate
      },
      returning: :aggregate_state
    )

    {:noreply, assign(socket, state: format(state))}
  end

  def handle_event("submit", %{"aggregate-type" => "status_page", "aggregate" => aggregate}, socket) do
    id = case Backend.Projections.Dbpa.StatusPage.status_page_by_name("SHARED", aggregate) do
      nil -> aggregate
      %{id: id} -> id
    end

    {:ok, state} = Backend.App.dispatch(
      %Domain.StatusPage.Commands.Print{
        id: id
      },
      returning: :aggregate_state
    )

    {:noreply, assign(socket, state: format(state))}
  end

  defp format(obj) do
    inspect(obj, pretty: true)
  end
end
