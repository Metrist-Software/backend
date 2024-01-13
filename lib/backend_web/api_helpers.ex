defmodule BackendWeb.ApiHelpers do
  @moduledoc """
  Miscellaneous helpers for the API
  """

  def get_datetime_from_iso_string(nil), do: nil
  def get_datetime_from_iso_string(iso_string) do
    {:ok, since_datetime, _offset_from_utc} = DateTime.from_iso8601(iso_string)
    DateTime.to_naive(since_datetime)
  end

  def get_datetime_from_param(nil), do: nil
  def get_datetime_from_param(param) when is_binary(param) do
    get_datetime_from_iso_string(param)
  end
  # OpenApiSpex.Plug.CastAndValidate will always give you the Etc/UTC but as a DateTime.
  # Just to_naive it since we need that
  def get_datetime_from_param(%DateTime{} = param) do
    DateTime.to_naive(param)
  end

  @doc """
  Returns a tuple of {from, to} when passed params
  Assumes from is in the "from"/:from key and to is in the "to"/:to key
  Will return nil for from or to if not present
  Will work with OpenApiSpex.Plug.CastAndValidate with replace_params:true as it will use atom keys
  """
  def get_daterange_from_params(params) when is_map_key(params, :from) or is_map_key(params, :to) do
    {get_datetime_from_param(params[:from]), get_datetime_from_param(params[:to])}
  end

  def get_daterange_from_params(params) do
    {get_datetime_from_param(params["from"]), get_datetime_from_param(params["to"])}
  end

  @doc """
  Converts the given `NaiveDateTime` to `DateTime` with `Etc/UTC` timezone
  """
  def naive_to_utc_dt(naive_dt) do
    DateTime.from_naive!(naive_dt, "Etc/UTC")
  end

  def validate_timerange(%NaiveDateTime{} = from, %NaiveDateTime{} = to)
      when from != nil
      when to != nil do
    if NaiveDateTime.compare(from, to) == :lt do
      :ok
    else
      {:error, "from must occur before to"}
    end
  end
  def validate_timerange(nil, _to), do: :ok
  def validate_timerange(_from, nil), do: :ok

  # Generates a custom API error in the same format as OpenApiSpex errors.
  def generate_error(detail, title) do
    %{
      errors: [
        %{
          detail: detail,
          title: title
        }
      ]
    }
  end
end
