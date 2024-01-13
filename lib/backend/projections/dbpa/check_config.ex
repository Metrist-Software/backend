defmodule Backend.Projections.Dbpa.CheckConfig do
  # no schema here as this is mapping a structure dumped directly into a Projection map

  require Logger

  use TypedStruct

  typedstruct do
    field :check_logical_name, String.t, enforce: true
    field :degraded_threshold, float
    field :error_down_count, integer
    field :error_up_count, integer
    field :degraded_down_count, integer
    field :degraded_up_count, integer
    field :degraded_timeout, integer
    field :error_timeout, integer
  end

  def get_empty(check \\ nil) do
    %__MODULE__{
      check_logical_name: check,
      degraded_threshold: nil,
      error_down_count: nil,
      error_up_count: nil,
      degraded_down_count: nil,
      degraded_up_count: nil,
      degraded_timeout: nil,
      error_timeout: nil
    }
  end

  def get_defaults(analyzer_config, check \\ nil) do
    %__MODULE__{
      check_logical_name: check,
      degraded_threshold: analyzer_config.default_degraded_threshold                 || 5.0,
      error_down_count: Map.get(analyzer_config, :default_error_down_count, 2)       || 2,
      error_up_count: Map.get(analyzer_config, :default_error_up_count, 2)           || 2,
      degraded_down_count: Map.get(analyzer_config, :default_degraded_down_count, 3) || 3,
      degraded_up_count: Map.get(analyzer_config, :default_degraded_up_count, 3)     || 3,
      degraded_timeout: Map.get(analyzer_config, :default_degraded_timeout, 900000)  || 900000,
      error_timeout: Map.get(analyzer_config, :default_error_timeout, 900000)        || 900000
    }
  end

  def fill_empty_with_defaults(check_config, analyzer_config) do
    %__MODULE__{
      check_config
      |
      degraded_threshold:  is_valid(check_config.degraded_threshold)  || is_valid(analyzer_config.default_degraded_threshold )  || 5.0,
      error_down_count:    is_valid(check_config.error_down_count)    || is_valid(analyzer_config.default_error_down_count)     || 2,
      error_up_count:      is_valid(check_config.error_up_count)      || is_valid(analyzer_config.default_error_up_count)       || 2,
      degraded_down_count: is_valid(check_config.degraded_down_count) || is_valid(analyzer_config.default_degraded_down_count)  || 3,
      degraded_up_count:   is_valid(check_config.degraded_up_count)   || is_valid(analyzer_config.default_degraded_up_count )   || 3,
      degraded_timeout:    is_valid(check_config.degraded_timeout)    || is_valid(analyzer_config.default_degraded_timeout  )   || 900000,
      error_timeout:       is_valid(check_config.error_timeout)       || is_valid(analyzer_config.default_error_timeout  )      || 900000
    }
  end

  defp is_valid(count) do
    case count do
      0->nil
      _->count
    end
  end

  def to_csharp_map(check_config) when is_nil(check_config), do: nil
  def to_csharp_map(check_config) do
    %{
      "CheckId" => check_config.check_logical_name,
      "DegradedThreshold" => check_config.degraded_threshold,
      "ErrorDownCount" => check_config.error_down_count,
      "ErrorUpCount" => check_config.error_up_count,
      "DegradedDownCount" => check_config.degraded_down_count,
      "DegradedUpCount" => check_config.degraded_up_count,
      "DegradedTimeout" => check_config.degraded_timeout,
      "ErrorTimeout" => check_config.error_timeout
    }
  end

  def from_csharp_map(csharp_check_config_map, analyzer_config) do
    defaults = get_defaults(analyzer_config)

    %__MODULE__
    {
      check_logical_name: Map.get(csharp_check_config_map, "CheckId"),
      degraded_threshold: Map.get(csharp_check_config_map, "DegradedThreshold", defaults.degraded_threshold),
      error_down_count: Map.get(csharp_check_config_map, "ErrorDownCount", defaults.error_down_count),
      error_up_count: Map.get(csharp_check_config_map, "ErrorUpCount", defaults.error_up_count),
      degraded_down_count: Map.get(csharp_check_config_map, "DegradedDownCount", defaults.degraded_down_count),
      degraded_up_count: Map.get(csharp_check_config_map, "DegradedUpCount", defaults.degraded_up_count),
      degraded_timeout: Map.get(csharp_check_config_map, "DegradedTimeout", defaults.degraded_timeout),
      error_timeout: Map.get(csharp_check_config_map, "ErrorTimeout", defaults.error_timeout),
    }
  end

  #Oddly enough, once an event comes back through commanded and gets deserialized we lose our quoted string keys
  def fix_lost_quoted_keys(cfg) do
    %{
      "CheckId" => Map.get(cfg, :CheckId),
      "DegradedThreshold" => Map.get(cfg, :DegradedThreshold),
      "ErrorDownCount" => Map.get(cfg, :ErrorDownCount),
      "ErrorUpCount" => Map.get(cfg, :ErrorUpCount),
      "DegradedDownCount" => Map.get(cfg, :DegradedDownCount),
      "DegradedUpCount" => Map.get(cfg, :DegradedUpCount),
      "DegradedTimeout" => Map.get(cfg, :DegradedTimeout),
      "ErrorTimeout" => Map.get(cfg, :ErrorTimeout)
    }
  end
 end
