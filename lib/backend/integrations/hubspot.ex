defmodule Backend.Integrations.Hubspot do
  require Logger

  @content_type {"content-type", "application/json"}
  # Contacts API
  # https://developers.hubspot.com/docs/api/crm/contacts

  def create_contact(properties) do
    properties =
      %{
        metrist_account_created_by: "Metrist Web App",
        metrist_last_login: "#{NaiveDateTime.to_string(NaiveDateTime.utc_now())} UTC",
        # Opt-in for all email updates
        receive_company_news: true,
        receive_product_updates_email: true,
        receive_weekly_report: true,
      }
      |> Enum.into(properties)

    with {:ok, id} <-
           "https://api.hubapi.com/crm/v3/objects/contacts"
           |> append_query_params()
           |> HTTPoison.post(Jason.encode!(%{properties: properties}), get_post_headers())
           |> decode_create_contact_response do
      {:ok, id}
    end
  end

  defp decode_create_contact_response(result) do
    case decode_response(result) do
      {:ok, %{"id" => id}} -> {:ok, id}
      # Contact might already exist in hubspot if they filled up the subscription form in the corporate website
      {:error, "Contact already exists. Existing ID: " <> id} -> {:ok, id}
      error -> error
    end
  end

  def update_contact(id, properties) do
    with {:ok, %{"properties" => p}} <-
           "https://api.hubapi.com/crm/v3/objects/contacts/#{id}"
           |> append_query_params()
           |> HTTPoison.patch(Jason.encode!(%{properties: properties}), get_post_headers())
           |> decode_response() do
      {:ok, p}
    end
  end

  def get_contact_properties(id, fields) when is_list(fields) do
    get_contact_properties(id, %{
      "properties" => Enum.join(fields, ",")
    })
  end

  def get_contact_properties(id, query_params) do
    with {:ok, %{"properties" => p}} <-
           "https://api.hubapi.com/crm/v3/objects/contacts/#{id}"
           |> append_query_params(query_params)
           |> HTTPoison.get(get_headers())
           |> decode_response() do
      {:ok, p}
    end
  end

  def get_property_details(property) do
    "https://api.hubapi.com/crm/v3/properties/contacts/#{property}"
    |> append_query_params()
    |> HTTPoison.get(get_headers())
    |> decode_response()
  end

  def get_property_group_details(property_group) do
    "https://api.hubapi.com/crm/v3/properties/contacts/groups/#{property_group}"
    |> append_query_params()
    |> HTTPoison.get(get_headers())
    |> decode_response()
  end

  def batch_create_contacts(inputs) do
    "https://api.hubapi.com/crm/v3/objects/contacts/batch/create"
    |> append_query_params()
    |> HTTPoison.post(Jason.encode!(%{inputs: inputs}), get_post_headers())
    |> decode_response()
  end

  def batch_create_contacts!(inputs), do: run_batch!(&batch_create_contacts/1, inputs)

  def batch_update_contacts(inputs) do
    "https://api.hubapi.com/crm/v3/objects/contacts/batch/update"
    |> append_query_params()
    |> HTTPoison.post(Jason.encode!(%{inputs: inputs}), get_post_headers())
    |> decode_response()
  end

  def batch_update_contacts!(inputs), do: run_batch!(&batch_update_contacts/1, inputs)

  def run_batch!(callback, args) do
    case callback.(args) do
      {:ok, %{"results" => results}} -> results
      {:error, reason} -> raise "Error: #{reason}"
    end
  end

  def list_contacts(query_params) do
    "https://api.hubapi.com/crm/v3/objects/contacts"
    |> append_query_params(query_params)
    |> HTTPoison.get(get_headers())
    |> decode_response()
  end

  # Properties API
  # https://developers.hubspot.com/docs/api/crm/properties
  # Note: Permissions are now needed in the Private App in
  # Hubspot for different object types

  def create_property(params, object_type) do
    "https://api.hubapi.com/crm/v3/properties/#{object_type}"
    |> append_query_params()
    |> HTTPoison.post(Jason.encode!(params), get_post_headers())
    |> decode_response()
  end

  def create_property_groups(params, object_type) do
    "https://api.hubapi.com/crm/v3/properties/#{object_type}/groups"
    |> append_query_params()
    |> HTTPoison.post(Jason.encode!(params), get_post_headers())
    |> decode_response()
  end

  # Legacy: https://legacydocs.hubspot.com/docs/methods/contacts/v2/get_contact_property_group

  def get_contact_property_group_details!(group_name, include_properties \\ false) do
    case get_contact_property_group_details(group_name, include_properties) do
      {:ok, response} -> response
      {:error, reason} -> raise "Failed to get contact property group details. Reason: #{reason}"
    end
  end

  def get_contact_property_group_details(group_name, include_properties \\ false) do
    "https://api.hubapi.com/properties/v1/contacts/groups/named/#{group_name}"
    |> append_query_params(%{includeProperties: include_properties})
    |> HTTPoison.get(get_headers())
    |> decode_response()
  end

  # Common helpers

  def append_query_params(url, query \\ %{}) do
    query =
      query
      |> URI.encode_query()

    "#{url}?#{query}"
  end

  def get_post_headers(), do: get_headers([@content_type])
  def get_headers(additional_headers \\ []) do
    additional_headers ++ [{"authorization", "Bearer #{Application.fetch_env!(:backend, :hubspot_app_token)}"}]
  end

  defp decode_response({:ok, %HTTPoison.Response{body: response_body}}) do
    with {:ok, body} <- Jason.decode(response_body) do
      case body do
        %{"status" => "error", "message" => message} ->
          Logger.error(message)
          {:error, message}
        body -> {:ok, body}
      end
    end
  end

  defp decode_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, reason}

  def format_date_property!(dt) when is_binary(dt) do
    # Assume ISO8601 datetime string
    dt
    |> NaiveDateTime.from_iso8601!()
    |> format_date_property!()
  end
  def format_date_property!(ndt = %NaiveDateTime{}) do
    ndt
    |> NaiveDateTime.to_date()
    |> Date.to_iso8601()
  end
  def format_date_property!(nil), do: nil
end
