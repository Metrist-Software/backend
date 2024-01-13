defmodule BackendWeb.Admin.Utilities.NoticesLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      notice: %Backend.Projections.Notice{},
      preview_notice: nil,
      notices: [],
      editing: []
    )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    notices = Backend.Projections.Notice.active_notices()

    {:noreply, assign(socket,
      notice: %Backend.Projections.Notice{},
      preview_notice: nil,
      notices: notices,
      editing: []
    )}
  end

  @impl true
  def handle_event("edit", %{"notice" => notice_id}, socket) do
    {:noreply, assign(socket,
      editing: [notice_id | socket.assigns.editing]
    )}
  end

  def handle_event("delete", %{"notice" => notice_id}, socket) do
    Backend.App.dispatch(%Domain.Notice.Commands.Clear{
      id: notice_id
    })

    {:noreply, assign(socket,
      notices: Enum.reject(socket.assigns.notices, &(&1.id == notice_id))
    )}
  end

  def handle_event("preview", %{"notice" => notice_id}, socket) do
    notice = Enum.find(socket.assigns.notices, &(&1.id == notice_id))
    {:noreply, assign(socket,
      preview_notice: %{notice | id: nil} # Ensure nil id so that marking read doesn't affect actual notice
    )}
  end

  @impl true
  def handle_info({:notice_created, notice}, socket) do
    {:noreply, assign(socket,
      notice: %Backend.Projections.Notice{},
      notices: [notice | socket.assigns.notices]
    )}
  end

  def handle_info({:notice_updated, notice}, socket) do
    {:noreply, assign(socket,
      editing: List.delete(socket.assigns.editing, notice.id)
    )}
  end

  def handle_info({:notice_edit_canceled, id}, socket) do
    {:noreply, assign(socket,
      editing: List.delete(socket.assigns.editing, id)
    )}
  end

  def handle_info({:notice_previewed, notice}, socket) do
    {:noreply, assign(socket,
      preview_notice: %{notice | id: nil}
    )}
  end
end
