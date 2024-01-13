defmodule BackendWeb.VerifyAuthController do
  use BackendWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false

  require Logger

  operation :get,
  summary: "Check if the API token key works, return 200 if it does",
  tags: ["Other"],
  responses: [
    ok: {"Valid API key", "text/plain", %OpenApiSpex.Schema{ type: :string }}
  ]

  @doc """
  Return errors of one or more monitors.
  """
  def get(conn, _params) do
    json(conn, :ok)
  end
end
