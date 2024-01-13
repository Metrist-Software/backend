defmodule BackendWeb.Components.Banner do
  use BackendWeb, :live_component

  # Bit of a hack for now. We want to hide the "Install app" notice banner if the account already has an app installed.
  # Instead of trying to target a specific notice, we'll just hide "all" of them, since it should only be the one
  # This'll need to be removed/updated for other notices that don't have conditional display
  @impl true
  def preload(list_of_assigns) do
    [%{user: user}|_] = list_of_assigns

    case Backend.Projections.get_account(user.account_id, [:microsoft_tenants, :slack_workspaces]) do
      nil ->
        list_of_assigns
      account ->
        if (Enum.any?(account.microsoft_tenants) || Enum.any?(account.slack_workspaces)) do
          Enum.map(list_of_assigns, &maybe_remove_notice/1)
        else
          list_of_assigns
        end
    end
  end

  defp maybe_remove_notice(assigns=%{force_show: true}), do: assigns
  defp maybe_remove_notice(assigns), do: Map.replace(assigns, :notice, nil)

  @impl true
  def render(assigns=%{notice: nil}) do
    ~H"<span />"
  end
  def render(assigns) do
    ~H"""
    <div class="p-3 bg-gray-100 drop-shadow prose prose-banner max-w-none text-black flex items-center">
      <div class="flex-grow">
        <%= parse_content(@notice.description) %>
      </div>
      <button type="button" phx-click="read" phx-target={@myself} class="h-full">
        <%= svg_image("icon-close", class: "h-10 w-10") %>
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("read", _params, socket) do
    Backend.App.dispatch(%Domain.Notice.Commands.MarkRead{
      id: socket.assigns.notice.id,
      user_id: socket.assigns.user.id
    })

    {:noreply, assign(socket, notice: nil)}
  end

  defp parse_content(nil), do: ""
  defp parse_content(body) do
    {:safe, body
            |> parse_markdown()
            |> parse_icons()}
  end

  defp parse_markdown(body) do
    case Earmark.as_html(body) do
      {:ok, html, _} -> html
      {:error, _, _} -> ""
    end
  end

  defp parse_icons(content) do
    String.replace(content, ~r/!icon-[\w-]+/, fn <<"!icon-", icon::binary>> ->
      try do
        icon
        |> svg_image()
        |> elem(1)
      rescue
        _ -> "!icon-#{icon}"
      end
    end)
  end
end
