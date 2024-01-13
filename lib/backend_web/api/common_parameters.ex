defmodule BackendWeb.API.CommonParameters do
  alias OpenApiSpex.Schema

  @moduledoc """
  This module contains common parameters for OpenAPISpecSchemas
  """
    def monitors(parameters \\ []) do
      parameters
      ++
      [
       m: [
          in: :query,
          description: """
          One or more monitors to get the errors for.
          These should be the logical names for the monitors.
          If omitted all monitors on the account are included
          """,
          required: true,
          schema: %Schema{type: :array, items: %Schema{type: :string}}
        ]
      ]
    end

    def checks(parameters \\ []) do
      parameters
      ++
      [
       c: [
          in: :query,
          description: "The checks to limit the query to",
          required: false,
          schema: %Schema{type: :array, items: %Schema{type: :string}}
        ]
      ]
    end

    def instances(parameters \\ []) do
      parameters
      ++
      [
       i: [
          in: :query,
          description: "The instances to limit the query to",
          required: false,
          schema: %Schema{type: :array, items: %Schema{type: :string}}
        ]
      ]
    end

    def include_shared(parameters \\ []) do
      parameters
      ++
      [ include_shared: [ in: :query, description: "Whether to include SHARED data in returned results. If omitted SHARED data will not be included", type: :boolean, required: false ] ]
    end

    def only_shared(parameters \\ []) do
      parameters
      ++
      [only_shared: [ in: :query, type: :boolean, description: "Whether to only return SHARED data in returned results. If omitted, the account specific data is returned", required: false ] ]
    end

    def from(parameters \\ [], opts \\ []) do
      parameters
      ++
      [from: [ in: :query, schema: %Schema{type: :string, format: :"date-time", description: "Start of datetime range in ISO_8601 format", example: "2022-04-21T14:58:17.175203Z"} ] ++ opts ]
    end

    def to(parameters \\ [], opts \\ []) do
      parameters
      ++
      [ to: [ in: :query, schema: %Schema{type: :string, format: :"date-time", description: "End of datetime range in ISO_8601 format", example: "2022-04-21T14:58:17.175203Z"} ] ++ opts ]
    end

    def cursor_after(parameters \\ []) do
      parameters
      ++
      [ cursor_after: [ in: :query, type: :string, description: "Fetch the records after this cursor.", required: false ] ]
    end

    def cursor_before(parameters \\ []) do
      parameters
      ++
      [ cursor_before: [ in: :query, type: :string, description: "Fetch the records before this cursor.", required: false ] ]
    end

    def limit(parameters \\ []) do
      parameters
      ++
      [ limit: [ in: :query, type: :integer, description: "Limit of the result set"] ]
    end
  end
