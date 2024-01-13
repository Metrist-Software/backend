defmodule BackendWeb.Components.DocPopup do
  @moduledoc """
  Simple pop-up to display documentation strings.
  """
  use BackendWeb, :component

  def render(assigns = %{module: module, tag: tag}) do
    description =
      tag
      |> module.description()
      |> String.replace(~r/\s+/, " ")

    assigns = assigns
    |> assign(:description, description)

    do_render(assigns)
  end

  # The simplest that could possible work for now: native browser tooltip. Having
  # an anchor here naturally extends into a "click for even more information" later on
  defp do_render(assigns = %{description: ""}), do: ~H""
  defp do_render(assigns) do
    ~H"""
    <a href="#" class="tooltip text-sm align-top" title={@description}>
      ⓘ
    </a>
    """
  end
end
