defmodule BackendWeb.Components.AccountMonitorSelection do
  use BackendWeb, :live_component

  @types %{account_id: :string, monitor_id: :string}
  @shared_account_id Domain.Helpers.shared_account_id()

  @default_assigns %{
    include_all_accounts_option: false,
    include_all_monitors_option: false
  }

  @impl true
  def update(assigns, socket) do
    assigns = Map.merge(@default_assigns, assigns)

    initial_account_id = @shared_account_id

    accounts = Backend.Projections.list_accounts(preloads: [:original_user])
    |> Enum.sort_by(& String.downcase(&1.name || &1.id))
    |> Enum.map(& {BackendWeb.Helpers.get_account_name_with_id(&1), &1.id})

    accounts = if assigns.include_all_accounts_option, do: [{"All", "all"} | accounts], else: accounts

    monitors = Backend.Projections.list_monitors(initial_account_id)
    |> monitor_dropdown_values(include_all_option: assigns.include_all_monitors_option)

    initial_monitor_id = if assigns.include_all_monitors_option, do: "all", else: List.first(monitors) |> elem(1)

    params = %{account_id: initial_account_id, monitor_id: initial_monitor_id}
    changeset = {%{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))

    send(self(), {:am_selected, initial_account_id, initial_monitor_id})

    socket = assign(socket,
      changeset: changeset,
      accounts: accounts,
      monitors: monitors,
      include_all_accounts_option: assigns.include_all_accounts_option,
      include_all_monitors_option: assigns.include_all_monitors_option
    )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@changeset} as={:form} phx-submit="submit" phx-change="change" phx-target={@myself}>
        <.form_field type="select" options={@accounts} form={f} field={:account_id} />
        <.form_field type="select" options={@monitors} form={f} field={:monitor_id} />
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("change", %{"form" => data}, socket) do
    changeset = {%{}, @types}
    |> Ecto.Changeset.cast(data, Map.keys(@types))
    |> Ecto.Changeset.validate_required([:account_id, :monitor_id])

    monitors = if changeset.valid? do
      account_id = case changeset.changes.account_id do
        "all" -> @shared_account_id
        id -> id
      end

      account_id
      |> Backend.Projections.list_monitors()
      |> monitor_dropdown_values(include_all_option: socket.assigns.include_all_monitors_option)
    else
      []
    end

    if changeset.valid? do
      send(self(), {:am_selected, changeset.changes.account_id, changeset.changes.monitor_id})
    end

    {:noreply, assign(socket, changeset: changeset, monitors: monitors)}
  end

  def handle_event(_event, _data, socket) do
    {:noreply, socket}
  end
end
