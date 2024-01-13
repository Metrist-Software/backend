defmodule BackendWeb.Component.APIToken do
  @doc """
  Auth token component. Generates or retrieves auth token for display.
  """

  use BackendWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, input_type: "password")}
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(:token_value, get_token(assigns))
      |> assign(assigns)
    }
  end

  @impl true
  def handle_event("toggle_hide", %{ "type" => input_type }, socket) do
    {
      :noreply,
      assign(socket, :input_type, switch_type(input_type))
    }
  end

  def handle_event("rotate_key", _params, socket) do
    account_id = socket.assigns.current_user.account_id
    existing_api_token = socket.assigns.token_value

    token = Backend.Auth.APIToken.rotate(account_id, socket, existing_api_token)

    {:noreply, assign(socket, token_value: token)}
  end

  def handle_event(_event, _value, socket), do: { :noreply, socket }

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"flex flex-row gap-3 #{@class}"}>
      <input type={@input_type} value={@token_value} id={"#{@id}-target"} class="basis-1/2" readonly="readonly" />
      <.button
        id={"#{@id}-btn"}
        phx-hook="ClickCopyToClipBoard"
        type="button"
        color="primary"
        data-target={"#{@id}-target"}
        disabled={@current_user.is_read_only}
        with_icon
      >
        <Heroicons.document_duplicate outline class="w-6 h-6" />
        Copy to clipboard
      </.button>

      <.button
        phx-click={click_event(@current_user.is_read_only)}
        phx-value-type={@input_type}
        phx-target={@myself}
        type="button"
        disabled={@current_user.is_read_only}
        with_icon
      >
        <Heroicons.eye_slash outline class="w-6 h-6" />
        <%= hide_text(@input_type) %>
      </.button>

      <.button
        icon={:arrow_path}
        phx-click="rotate_key"
        phx-target={@myself}
        disabled={@current_user.is_read_only}
        type="button"
        data-confirm="Are you sure you want to replace this api key?"
      >
        Rotate
      </.button>
    </div>
    """
  end

  defp get_token(assigns = %{ value_kind: "auth", current_user: %{ account_id: id, is_read_only: false } }) do
    # Generate token or retrieve existing one
    case Backend.Auth.APIToken.list(id) do
      [] ->
          Backend.Auth.APIToken.generate(id, assigns.current_user)
      [first | _] ->
          first
    end
  end
  defp get_token(%{ value_kind: "auth", current_user: %{ is_read_only: true } }) do
    # TODO: dummy string until we implement read-only keys
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  end

  defp switch_type("password"), do: "text"
  defp switch_type("text"), do: "password"

  # button text based on input type
  defp hide_text("password"), do: "Unhide"
  defp hide_text("text"), do: "Hide"

  # disable phx-click when is-read-only user
  defp click_event(false), do: "toggle_hide"
  defp click_event(_), do: ""
end
