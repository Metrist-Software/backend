defmodule Mix.Tasks.Metrist.GenerateManifestDocs do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :env
  ]

  @shortdoc "Generate doc modules from monitor manifests"
  @moduledoc """
  Pulls the aggregated monitor manifest and uses it to build up various docs modules. Depending on
  the value for env passed, it will either download the prod or dev preview manifest. For local,
  this will build the aggregated manifest on the fly. Note that it is assumed that the monitors
  repo is checked out beside the backend repo.

  #{Helpers.gen_command_line_docs(@opts)}

  ## Example:

      mix metrist.generate_manifest_docs -e local
  """

  defp source_from_env("local") do
    # Generation of combined manifest is now quite complicated
    # with monitor and package manifests and the need for them to be joined
    # Go to the manifests-preview.json for local
    source_from_env("dev")
  end

  defp source_from_env("dev") do
    "https://monitor-distributions.metrist.io/manifests-preview.json"
    |> HTTPoison.get!()
    |> Map.get(:body)
  end

  defp source_from_env(_) do
    "https://monitor-distributions.metrist.io/manifests.json"
    |> HTTPoison.get!()
    |> Map.get(:body)
  end

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    [:hackney, :jason]
    |> Enum.each(&Application.ensure_all_started/1)

    manifests = opts.env
    |> source_from_env()
    |> Jason.decode!(keys: :atoms)
    |> Map.get(:monitors)
    |> Enum.sort_by(& &1.logical_name)

    manifests
    |> build_monitors_ex()
    |> write_to_file("lib/backend/docs/generated/monitors.ex")

    manifests
    |> build_checks_ex()
    |> write_to_file("lib/backend/docs/generated/check.ex")
  end

  defp build_monitors_ex(manifests) do
    monitor_names = Enum.map(manifests, fn manifest ->
      {manifest.logical_name, manifest.name}
    end)
    |> Enum.uniq_by(& elem(&1, 0))

    monitor_status_pages = Enum.map(manifests, fn manifest ->
      {manifest.logical_name, Map.get(manifest, :status_page_url)}
    end)

    monitors_by_group = Enum.reduce(manifests, %{}, fn curr, acc ->
      groups = case Map.get(curr, :groups) do
        nil -> ["other"]
        groups -> groups
      end

      groups
      |> Enum.map(& {&1, [curr.logical_name]})
      |> Map.new()
      |> Map.merge(acc, fn _key, val1, val2 -> val1 ++ val2 end)
    end)
    |> Enum.map(fn {group, monitors} ->
      result = monitors
      |> Enum.uniq()
      |> Enum.sort()
      {group, result}
    end)

    monitor_groups =
      for manifest <- manifests,
        into: %{},
        do: {manifest.logical_name, manifest.groups}

    all_monitors_ast = quote do
      def all() do
        unquote(Enum.map(monitor_names, fn {logical_name, _name} -> logical_name end))
      end
    end

    monitor_name_asts = Enum.map(monitor_names, fn {logical_name, name} ->
      quote do
        def name(unquote(logical_name)) do
          unquote(name)
        end
      end
    end)

    monitor_group_asts = Enum.map(monitors_by_group, fn {group, monitors} ->
      quote do
        def monitors_for_group(unquote(group)) do
          unquote(monitors)
        end
      end
    end)

    monitor_status_page_asts = Enum.map(monitor_status_pages, fn {logical_name, spurl} ->
      quote do
        def status_page(unquote(logical_name)) do
          unquote(spurl)
        end
      end
    end)

    monitor_description_asts =  Enum.map(manifests, fn manifest ->
      quote do
        def description(unquote(manifest.logical_name)) do
          unquote(Map.get(manifest, :description, ""))
        end
      end
    end)

    quote do
      defmodule Backend.Docs.Generated.Monitors do
        unquote(all_monitors_ast)

        @monitor_groups unquote(Macro.escape(monitor_groups))
        def monitor_groups(logical_name) when is_map_key(@monitor_groups, logical_name), do: @monitor_groups[logical_name]
        def monitor_groups(_), do: []

        unquote_splicing(monitor_group_asts)
        def monitors_for_group(_), do: []

        unquote_splicing(monitor_name_asts)
        def name(monitor_id), do: monitor_id

        unquote_splicing(monitor_description_asts)
        def description(_), do: ""

        unquote_splicing(monitor_status_page_asts)
        def status_page(_), do: nil
      end
    end
  end

  defp build_checks_ex(manifests) do
    check_names_by_monitor = Enum.flat_map(manifests, fn manifest ->
      Enum.flat_map(Map.get(manifest, :packages, []), fn package ->
        Enum.map(package.steps, fn step ->
          {manifest.logical_name, step.logical_name, step.name}
        end)
      end)
    end)
    |> Enum.group_by(
      & elem(&1, 0),
      fn {_monitor_logical_name, check_logical_name, check_name} ->
        {check_logical_name, check_name}
      end
    )

    check_name_asts = Enum.flat_map(check_names_by_monitor, fn {monitor_logical_name, check_names} ->
      Enum.map(check_names, fn {check_logical_name, check_name} ->
        quote do
          def name(unquote(monitor_logical_name), unquote(check_logical_name)) do
            unquote(check_name)
          end
        end
      end)
    end)

    check_description_asts = Enum.flat_map(manifests, fn manifest ->
      Enum.flat_map(Map.get(manifest, :packages, []), fn package ->
        Enum.map(package.steps, fn step ->
          quote do
            def description(unquote(manifest.logical_name), unquote(step.logical_name)) do
              unquote(step.description)
            end
          end
        end)
      end)
    end)

    check_docs_url_asts = Enum.flat_map(manifests, fn manifest ->
      Enum.flat_map(Map.get(manifest, :packages, []), fn package ->
        Enum.map(package.steps, fn step ->
          quote do
            def docs_url(unquote(manifest.logical_name), unquote(step.logical_name)) do
              unquote(Map.get(step, :docs_url, ""))
            end
          end
        end)
      end)
    end)

    quote do
      defmodule Backend.Docs.Generated.Checks do
        unquote_splicing(check_name_asts)
        def name(_, check_id), do: check_id

        unquote_splicing(check_description_asts)
        def description(_, _), do: ""

        unquote_splicing(check_docs_url_asts)
        def docs_url(_, _), do: ""
      end
    end
  end

  defp write_to_file(ast, filename) do
    File.write(filename, Macro.to_string(ast))
  end
end
