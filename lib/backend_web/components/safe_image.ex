defmodule BackendWeb.Components.SafeImage do
  use BackendWeb, :live_component

  # TODO: Handle errors loading image
  def mount(socket) do
    {:ok, assign(socket,
       src: "",
       class: "",
       alt: "")}
  end

  def render(assigns) do
    ~H"""
    <img src={img_src(@src)} class={@class} alt={@alt} />
    """
  end


  defp img_src(nil), do: "/images/default.png"
  defp img_src(""), do: "/images/default.png"
  defp img_src(src), do: src
end
