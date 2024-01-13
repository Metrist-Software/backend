defmodule Backend.Projections.Dbpa.Monitor do
  use Ecto.Schema

  @primary_key {:logical_name, :string, []}
  schema "monitors" do
    field :name, :string
    field :last_analysis_run_at, :utc_datetime
    field :last_analysis_run_by, :string

    has_one :analyzer_config,
      {"analyzer_configs", Backend.Projections.Dbpa.AnalyzerConfig},
      foreign_key: :monitor_logical_name
    has_many :monitor_configs, Backend.Projections.Dbpa.MonitorConfig,
      foreign_key: :monitor_logical_name
    has_many :instances, Backend.Projections.Dbpa.MonitorInstance,
      foreign_key: :monitor_logical_name
    has_many :checks, Backend.Projections.Dbpa.MonitorCheck,
      foreign_key: :monitor_logical_name
    has_one :monitor_tags, Backend.Projections.Dbpa.MonitorTags,
      foreign_key: :monitor_logical_name
    has_many :subscriptions, Backend.Projections.Dbpa.Subscription,
      foreign_key: :monitor_id

    timestamps()
  end

  def get_tags(nil), do: []
  def get_tags(%__MODULE__{monitor_tags: nil}), do: []
  def get_tags(%__MODULE__{monitor_tags: %Ecto.Association.NotLoaded{}}), do: []
  def get_tags(%__MODULE__{monitor_tags: %{tags: tags}}), do: tags

  def get_checks(nil), do: []
  def get_checks(%__MODULE__{checks: nil}), do: []
  def get_checks(%__MODULE__{checks: %Ecto.Association.NotLoaded{}}), do: []
  def get_checks(%__MODULE__{checks: checks}), do: checks
end
