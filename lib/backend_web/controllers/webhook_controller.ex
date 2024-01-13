defmodule BackendWeb.WebhookController do
  use BackendWeb, :controller

  require Logger
  alias Backend.Projections

  @moduledoc """
  Receives incoming webhooks webhook request
  """

  use TypedStruct

  typedstruct module: Webhook, enforce: true do
    @derive Jason.Encoder

    @moduledoc """
    Format for returned Webhook
    """
    field :monitor_logical_name, :string
    field :instance_name, :string
    field :data, :string
    field :content_type, :string
    field :inserted_at, :string
  end

  def receive(conn, _params = %{"monitor" => monitor_id, "instance" => instance_id}) do
    body = BackendWeb.Plugs.CachingBodyReader.get_raw_body(conn)
    headers = Enum.into(conn.req_headers, %{})
    Projections.Webhook.store(monitor_id, instance_id, body, headers["content-type"])
    conn |> json(%{status: :ok})
  end

  def get_by_uid(conn, params = %{"uid" => uid, "monitor" => monitor_id, "instance" => instance_id}) do
    Logger.info("#{inspect params}")
    case Projections.Webhook.find(uid, monitor_id, instance_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text(:"404")
      item ->
        conn
        |> json(%Webhook{
          monitor_logical_name: item.monitor_logical_name,
          instance_name: item.instance_name,
          data: item.data,
          content_type: item.content_type,
          inserted_at: item.inserted_at
        })
    end
  end
end
