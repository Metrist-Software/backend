defmodule BackendWeb.DocsLive do
  use BackendWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    path = Map.get(params, "path", "index")
    socket =
      socket
      |> setup_page_for(path)
      |> assign(page_title: "Docs")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="prose prose-doc dark:prose-dark ">
      <%= @doc_body %>
    </div>
    """
  end

  defp setup_page_for(socket, path) do
    with md <- fetch(path),
         {:ok, html, _msgs} = Earmark.as_html(md)
      do
      assign(socket, :doc_body, {:safe, html})
    end
  end

  defp fetch("index") do
    """
    # Documentation index

    * [General overview](/docs/general)
    * [Metrist Agent Source Code](/docs/agent)
    * [Ruby In-Process Agent](/docs/ruby_ipa)
    * [PHP/Curl In-Process Agent](/docs/php_ipa)

    """
  end
  defp fetch(name) do
    # We can hardcode things, we only have one bucket. If we ever want to
    # run this locally, it's easy enough to test for Mix.env being not-prod and
    # grabbing the files from the filesystem
    op = ExAws.S3.get_object("canary-shared-dist", "all/docs-sources/#{name}.md")
    {:ok, %{body: body}} = ExAws.request(op, region: "us-west-2")
    body
  end
end
