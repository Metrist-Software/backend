defmodule BackendWeb.DistributionsLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        breadcrumbs: [],
        prefixes: [],
        contents: [],
        page_title: "Distributions")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    path =
      case Map.get(params, "path") do
        nil ->
          []

        # A bit dirty. We reference a string ("a/b/c") path in links,
        # while deeplinks come in as a list path (["a", "b", "c"]). It's easier and i
        # all we have # to do is this little conversion step.
        [path] ->
          path
          |> String.split("/")
          |> Enum.filter(fn e -> e != "" end)

        path ->
          path
      end

    socket =
      if connected?(socket) do
        setup_page_for(path, socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div>
      <h2 class="mb-3 text-3xl">
        Distributions
      </h2>

      <ul class="flex mb-8 px-4 py-3 rounded bg-gray-200 dark:bg-gray-900">
        <li class="flex">
          <.link patch={Routes.live_path(@socket, BackendWeb.DistributionsLive, [])} class="text-blue-700 hover:underline focus:underline">
            Home
          </.link>
          <span class="px-1">/</span>
        </li>

        <%  last = Enum.at(@breadcrumbs, -1) %>
        <%= for {crumb, path} <- @breadcrumbs do %>
          <li class="flex">
            <%= if {crumb, path} == last do %>
              <%= crumb %>
            <% else %>
              <.link patch={Routes.live_path(@socket, BackendWeb.DistributionsLive, [path])} class="text-blue-700 hover:underline focus:underline">
              <%= crumb %>
              </.link>
            <% end %>
            <span class="px-1">/</span>
          </li>
        <% end %>
      </ul>

      <div class="lg:flex">
        <div class="lg:w-1/3 lg:pr-8 mb-5">
          <h2 class="mb-5 text-xl">
            Directories
          </h2>

          <%= if @prefixes == [] do %>
            <div class="text-muted px-4">
              No sub-directories in this directory
            </div>
          <% else %>
            <ul class="box overflow-hidden divide-y dark:divide-gray-600 break-words">
              <%= for prefix <- @prefixes do %>
                <li>
                  <.link patch={Routes.live_path(@socket, BackendWeb.DistributionsLive, [prefix])} class="block px-4 py-3 hover:bg-gray-200 focus:bg-gray-200 dark:hover:bg-gray-700 dark:focus:bg-gray-700">
                    <%= dirname(prefix) %>
                  </.link>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>

        <div class="lg:w-2/3">
          <h2 class="mb-5 text-xl">
            Files
          </h2>


          <%= if @contents == [] do %>
            <div class="text-muted px-4">
              No files in this directory
            </div>
          <% else %>
            <ul class="box overflow-hidden divide-y dark:divide-gray-600 break-words">
              <%= for file <- @contents do %>
                <li>
                  <a href={sign(file)}
                     class="block px-4 py-3 hover:bg-gray-200 focus:bg-gray-200 dark:hover:bg-gray-700 dark:focus:bg-gray-700">
                    <%= filename(file) %>
                  </a>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp setup_page_for(path, socket) do
    {prefixes, contents, crumbs} = dir(path)

    assign(socket,
      prefixes: prefixes,
      contents: contents,
      breadcrumbs: crumbs
    )
  end

  defp dir(path) do
    settings = settings_as_map()

    prefix =
      case Enum.join(path, "/") do
        "" -> ""
        prefix -> "#{prefix}/"
      end

    op = ExAws.S3.list_objects_v2(settings.bucket_name, prefix: prefix, delimiter: "/")

    {:ok, %{body: %{common_prefixes: prefixes, contents: contents}}} =
      ExAws.request(op, region: settings.region)

    prefixes = Enum.map(prefixes, & &1.prefix)
    contents = Enum.map(contents, & &1.key)
    {prefixes, contents, breadcrumbify(path)}
  end

  defp breadcrumbify(path) do
    {crumbs, _} =
      path
      |> Enum.map_reduce("", fn dir, parent ->
        new_parent = String.trim_leading("#{parent}/#{dir}", "/")
        {{dir, new_parent}, new_parent}
      end)

    crumbs
  end

  defp sign(object) do
    settings = settings_as_map()

    aws_key = Application.get_env(:backend, :distributions_signing_key)
    conf = %{
      secret_access_key: Keyword.get(aws_key, :secret_access_key),
      access_key_id: Keyword.get(aws_key, :access_key_id),
      region: settings.region,
      host: "s3.#{settings.region}.amazonaws.com",
      scheme: "https://"
    }

    {:ok, url} =
      ExAws.S3.presigned_url(
        conf,
        :get,
        settings.bucket_name,
        object,
        virtual_host: true,
        expires_in: 86400
      )

    url
  end

  defp dirname(path) do
    path
    |> String.split("/")
    |> Enum.at(-2)
    |> Kernel.<>("/")
  end

  defp filename(path) do
    path
    |> String.split("/")
    |> Enum.at(-1)
  end

  defp settings_as_map() do
    Application.get_env(:backend, Distributions) |> Map.new()
  end
end
