defmodule Backend.Projections.Dbpa.AnalyzerConfig do
  use Ecto.Schema
  use TypedStruct

  @primary_key {:monitor_logical_name, :string, []}
  schema "analyzer_configs" do
    field :default_degraded_threshold, :float
    field :default_degraded_down_count, :integer
    field :default_degraded_up_count, :integer
    field :default_degraded_timeout, :integer
    field :default_error_timeout, :integer
    field :default_error_down_count, :integer
    field :default_error_up_count, :integer
    field :instances, {:array, :string}
    field :check_configs, {:array, :map}

    timestamps()
  end

  def fill_empty_with_defaults(analyzer_config) do
    %__MODULE__{
      analyzer_config
      |
      default_degraded_threshold: analyzer_config.default_degraded_threshold || 5,
      default_degraded_down_count: analyzer_config.default_degraded_down_count || 3,
      default_degraded_up_count: analyzer_config.default_degraded_up_count || 3,
      default_degraded_timeout: analyzer_config.default_degraded_timeout || 900000,
      default_error_timeout: analyzer_config.default_error_timeout || 900000,
      default_error_down_count: analyzer_config.default_error_down_count || 2,
      default_error_up_count: analyzer_config.default_error_up_count || 2
    }
  end

  @doc """
  Utility funciton that converts a Domain.Monitor.Events.AnalyzerConfigUpdated
  or Domain.Monitor.Events.AnalyzerConfigAdded to the DBPA representation
  """
  @spec from_event(%Domain.Monitor.Events.AnalyzerConfigUpdated{} | %Domain.Monitor.Events.AnalyzerConfigAdded{}) :: %__MODULE__{}
  def from_event(event) do
    fixed_check_configs =
      event.check_configs
      |> Enum.map(fn cfg ->
        # This is hacky but oddly enough, once the event comes back through commanded and gets deserialized we lose our quoted string keys
        # TODO in the future handle this in Jason deserialization instead
        case Map.get(cfg, :CheckId) do
          nil -> cfg # we haven't lost our quoted string keys
          _ -> Backend.Projections.Dbpa.CheckConfig.fix_lost_quoted_keys(cfg)
        end
      end)

    %__MODULE__{
      monitor_logical_name: event.monitor_logical_name,
      default_degraded_threshold: event.default_degraded_threshold,
      default_degraded_down_count: event.default_degraded_down_count,
      default_degraded_up_count: event.default_degraded_up_count,
      default_degraded_timeout: event.default_degraded_timeout,
      default_error_timeout: event.default_error_timeout,
      default_error_down_count: event.default_error_down_count,
      default_error_up_count: event.default_error_up_count,
      instances: event.instances,
      check_configs: fixed_check_configs
    }
  end

  @doc """
  We can either have our CheckConfigs as a map or as CheckConfig structs
  This will ensure they are all in CheckConfig struct format
  """
  @spec transform_check_configs(%__MODULE__{}) :: %__MODULE__{}
  def transform_check_configs(analyzer_config) do
    transformed_check_configs =
      Map.get(analyzer_config, :check_configs, [])
      |> Enum.map(fn cfg ->
        case Map.get(cfg, :__struct__) do
          Backend.Projections.Dbpa.CheckConfig -> cfg # already a checkconfig
          _ -> Backend.Projections.Dbpa.CheckConfig.from_csharp_map(cfg, analyzer_config) # change to a check config
        end
      end)
    %__MODULE__{analyzer_config | check_configs: transformed_check_configs}
  end
end
