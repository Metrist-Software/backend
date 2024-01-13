defmodule BackendWeb.AppsSlackLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Install Slack App",
        step_contents: nil,
        step_title: nil,
        complete: false,
        override_title: nil,
        workspaces: [])

     {:ok, socket}
  end

  @impl true
  def handle_params(%{"callback" => _, "code" => code, "state" => state}, _uri, socket) do
    # Handle Slack's callback - the connection request is complete and that
    # means we can continue in the wizard. It's a bit odd that we handle an OAuth2
    # callback in LiveView - given that we create side effects here we only process
    # on the second call, when the socket is connected.
    if connected?(socket) do
      cmd = %Domain.SlackIntegration.Commands.CompleteConnection{
        id: state,
        code: code
      }

      # The completion event will land on the account. We subscribe, push the
      # "confirm" page which has the spinner, and when PubSub signals the event,
      # our handle_info will then redirect to the last page. Note that a success
      # state we receive from an account event while a failure state comes as
      # an integration event.
      Backend.PubSub.subscribe("Account:#{socket.assigns.current_user.account_id}")
      Backend.PubSub.subscribe_to_topic_of(cmd)
      Backend.App.dispatch(cmd)
      {:noreply, push_patch(socket, to: Routes.apps_slack_path(socket, :confirm))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    # Default handle_params, which we use to stash the URI. We'll need that later
    # to tell Slack where to redirect back to.
    {:noreply, socket
    |> assign(uri: uri)
    |> maybe_assign_workspaces()
    |> assign_step_contents()
    |> assign_step_title()}
  end

  defp maybe_assign_workspaces(socket) do
    case socket.assigns.live_action do
      :start ->
        workspaces =
           socket
           |> BackendWeb.Helpers.account_id()
           |> Backend.Projections.get_slack_workspaces()

           assign(socket, workspaces: workspaces)
      _ -> socket
    end
  end

  defp assign_step_contents(%Phoenix.LiveView.Socket{assigns: assigns} = socket),
    do: assign(socket, :step_contents, step_contents(assigns.live_action, assigns))

  defp assign_step_title(%Phoenix.LiveView.Socket{assigns: assigns} = socket) do
    assign(socket, :step_title, step_title(assigns.live_action, assigns))
  end

  @impl true
  def handle_event("associate", _params, socket) do

    redirect_url = socket.assigns.uri
    |> URI.parse()
    |> URI.append_query("callback=true")
    |> URI.to_string()

    # Start the connection request and redirect the user to Slack's OAuth2 page.
    cmd = %Domain.SlackIntegration.Commands.RequestConnection{
      id: Domain.Id.new(),
      account_id: socket.assigns.current_user.account_id,
      redirect_to: redirect_url
    }
    case BackendWeb.Helpers.dispatch_with_auth_check(socket,cmd) do
      {:error, _} -> {:noreply, socket}
      _ -> {:noreply, jump_to_slack(socket, cmd)}
    end
  end

  @impl true
  def handle_info(m = %{event: %Domain.Account.Events.SlackWorkspaceAttached{}}, socket) do
    if m.event.id == socket.assigns.current_user.account_id do
      {:noreply, socket
      |> assign(override_title: "#{m.event.message}!")
      |> push_patch(to: Routes.apps_slack_path(socket, :complete))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(m = %{event: %Domain.SlackIntegration.Events.ConnectionFailed{}}, socket) do
    is_informational = m.event.existing_account_id == socket.assigns.current_user.account_id
    {:noreply, socket
     |> assign(is_informational: is_informational,
               message: m.event.reason)
     |> push_patch(to: Routes.apps_slack_path(socket, :failed))}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp jump_to_slack(socket, cmd) do
    redirect(socket,
      external: Backend.Integrations.Slack.slack_oauth_url(cmd.id, cmd.redirect_to)
    )
  end

  # Wizard stuff. This wizard is a bit simpler than the signup one so let's
  # try to do it without components.

  def render_start(assigns) do
    ~H"""
    <div class="mb-5">
      <%= case length(@workspaces) > 0 do %>
      <% true -> %>
        <p class="mb-3"><%= str("pages.apps.slack.connectedWorkspaces") %></p>
      <% _ -> %>
        <p class="mb-3"><%= str("pages.apps.slack.noConnectedWorkspaces") %></p>
      <% end %>

      <ul class="list-disc list-inside">
      <%= for workspace <- @workspaces do %>
        <li><%= workspace.team_name %></li>
      <% end %>
      </ul>
    </div>

    <%= if @current_user.is_read_only do %>
      <p class="mb-3"><%= str("pages.apps.slack.readOnlyForbidden") %></p>
    <% end %>

    <%= if not @current_user.is_read_only do %>
      <div class="mb-5 prose dark:prose-dark">
      <%= str("pages.apps.slack.description") %>
      </div>

      <button id="associate-slack"
      phx-click="associate">
        <img alt="Add to Slack" height="40" width="139" src="https://platform.slack-edge.com/img/add_to_slack.png" srcSet="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x" />
      </button>
    <% end %>

    """
  end

  def render_confirm(assigns) do
    ~H"""
      <p class="mb-5">
        <%= str("pages.apps.slack.callback.processing") %>
      </p>

      <div class="flex items-center">
        <.spinner size="sm" class="mr-1"/><%= str("messages.pleaseWait") %>
      </div>
    """
  end

  @complete_body (with priv_dir <- Application.app_dir(:backend, "priv"),
                       filename <- Path.join(priv_dir, "slack-completion.md"),
                       contents <- File.read!(filename),
                       {:ok, html, _msgs} <- Earmark.as_html(contents) do
                    html
                  end)

  @spec render_complete(map) :: Phoenix.LiveView.Rendered.t()
  def render_complete(assigns) do
    assigns = Map.put(assigns, :body, {:safe, @complete_body})

    ~H"""
    <div class="prose dark:prose-dark max-w-none">
      <%= @body %>
    </div>
    """
  end

  def render_failed(assigns) do
    ~H"""
    <p class="mb-5"><%= str("pages.apps.slack.callback.failure") %></p>

    <%= if assigns[:message] && assigns[:is_informational] do %>
      <.alert color="info" label={@message} />
    <% end %>
    <button class={button_class()}
            onclick={"window.location.href='#{Routes.apps_slack_path(BackendWeb.Endpoint, :start)}';"}>Try again</button>
    """
  end

  # Step helpers

  @steps %{
    start: 0,
    confirm: 1,
    complete: 2,
    failed: 2
  }

  def step_of(live_action) do
    Map.get(@steps, live_action)
  end

  def step_contents(live_action, assigns) do
    fun =
      case live_action do
        :start -> &render_start/1
        :confirm -> &render_confirm/1
        :complete -> &render_complete/1
        :failed -> &render_failed/1
      end

    fun.(assigns)
  end

  def step_title(live_action, assigns) do
    case Map.get(assigns, :override_title) do
      nil ->
        key = case live_action do
          :start -> "pages.apps.slack.title"
          :confirm -> "pages.apps.slack.callback.title"
          :complete -> "pages.apps.slack.complete.title"
          :failed -> "pages.apps.slack.failed.title"
        end

        BackendWeb.I18n.str(key)
      title -> title
    end
  end
end
