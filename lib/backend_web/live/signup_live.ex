defmodule BackendWeb.SignupLive do
  use BackendWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) and socket.assigns.current_user.account_id == nil do
      send(self(), :signup)
    end

    {:ok, assign(socket, :hide_breadcrumb, true)}
  end

  @impl true
  def handle_info(:signup, socket) do
    # current_user = socket.assigns.current_user
    # # Domain.Account.Events.UserAdded will fire before the account_id is set so
    # # subscribe to the actual UserAggregate and listen for the Update
    # interested_command = %Domain.User.Commands.Update{
    #   id: socket.assigns.current_user.id
    # }
    # Backend.PubSub.subscribe_to_topic_of(interested_command)

    # account_id = Domain.Id.new()
    # cmd = %Domain.Account.Commands.Create{
    #   id: account_id,
    #   creating_user_id: socket.assigns.current_user.id,
    #   name: nil,
    #   selected_monitors: [],
    #   selected_instances: []
    # }
    # Backend.PubSub.subscribe_to_topic_of(cmd)

    # BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)

    # # And now we wait...
    # {:noreply,
    #   socket
    #   |> push_event("gtm-signup", %{email: current_user.email})
    # }
    {:noreply, socket}
  end


  def handle_info(%{event: %Domain.User.Events.AccountIdUpdate{id: user_id, user_account_id: _account_id}}, socket) do
    if user_id == socket.assigns.current_user.id do
      # We can't set cookies from a LiveView, so we redirect through the auth controller
      Logger.info("Got AccountIdUpdate for user. Redirecting to reauth")
      {:noreply, redirect(socket, to: "/auth/reauth")}
    else
      # Someone else signed up, do nothing
      {:noreply, socket}
    end
  end

  def handle_info(:skip, socket) do
    {:noreply, redirect(socket, to: "/auth/reauth")}
  end

  def handle_info(_any, socket) do
    {:noreply, socket}
  end
end
