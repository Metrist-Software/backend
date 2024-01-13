defmodule BackendWeb.API.RenderSpec do
  @moduledoc """
  Forces our in: query arrays to render in the spec with square brackets (eg. m[] )

  open_api_spex validator needs the parameter named "m" but SwaggerUI needs it named "m[]"
  """

  @behaviour Plug

  require Logger

  @json_encoder Enum.find([Jason, Poison], &Code.ensure_loaded?/1)

  @impl Plug
  def init(opts), do: opts

  if @json_encoder do
    @impl Plug
    def call(conn, _opts) do
      # credo:disable-for-this-file Credo.Check.Design.AliasUsage
      {spec, _} = OpenApiSpex.Plug.PutApiSpec.get_spec_and_operation_lookup(conn)

      spec =
        spec
        |> add_brackets_to_in_query_arrays()

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, @json_encoder.encode!(spec))
    end
  else
    IO.warn("No JSON encoder found. Please add :json or :poison in your mix dependencies.")

    @impl Plug
    def call(conn, _opts), do: conn
  end

  # open_api_spex validator needs the parameter named "m" but SwaggerUI and external consumers need to be told that it is m[]
  # ultimately this is a bug where open_api_spex validator doesn't handle m[] names properly and complains that m cannot be found
  # as phoenix turns m[]=1&m[]=2 into m in the params and that doesn't match the name of m[]
  # here we are only fixing this on "get" operations
  # If we have an in query parameter which is an array, append "[]" to the name
  defp add_brackets_to_in_query_arrays(spec) do
    updated_paths =
      Map.get(spec, :paths, %{})
      |> Enum.reduce(%{}, fn {key, path_item}, acc ->
        updated_path_item = maybe_update_path_item(path_item)
        Map.put(acc, key, updated_path_item)
      end)
    Map.put(spec, :paths, updated_paths)
  end

  defp maybe_update_path_item(%OpenApiSpex.PathItem{get: %OpenApiSpex.Operation{} = operation} = item) when not is_nil(operation) do
    updated_parameters =
      Enum.map(operation.parameters, fn parameter ->
        maybe_update_array_parameter(parameter)
      end)
    operation = %{ operation | parameters: updated_parameters }
    %{item | get: operation}
  end
  defp maybe_update_path_item(%OpenApiSpex.PathItem{} = item), do: item

  defp maybe_update_array_parameter(%OpenApiSpex.Parameter{in: :query, schema: %{type: :array}} = parameter) do
    %{ parameter | name: String.to_atom("#{Atom.to_string(parameter.name)}[]") }
  end

  defp maybe_update_array_parameter(%OpenApiSpex.Parameter{} = parameter), do: parameter
end
