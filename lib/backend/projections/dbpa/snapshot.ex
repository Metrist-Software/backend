defmodule Backend.Projections.Dbpa.Snapshot do
  use TypedStruct
  use Ecto.Schema

  @type state :: :up | :degraded | :issues | :down | :blocked | :unknown

  @state_up :up
  @state_degraded :degraded
  @state_issues :issues
  @state_down :down
  @state_blocked :blocked
  @state_unknown :unknown

  typedstruct module: CheckDetail do
    plugin Backend.JsonUtils

    field :name, String.t()
    field :check_id, String.t()
    field :instance, String.t()
    field :state, Backend.RealTimeAnalytics.Snapshotting.state()
    field :average, float()
    field :current, float()
    field :message, String.t()
    field :created_at, NaiveDateTime.t()
    field :last_checked, NaiveDateTime.t()
  end

  typedstruct module: Snapshot do
    @derive Jason.Encoder
    field :id, String.t()
    field :state, Backend.RealTimeAnalytics.Snapshotting.state
    field :message, String.t()
    field :monitor_id, String.t()
    field :last_checked, NaiveDateTime.t()
    field :last_updated, NaiveDateTime.t()
    field :check_details, list(CheckDetail.t())
    field :status_page_component_check_details, list(CheckDetail.t()), default: []
    field :correlation_id, String.t()
  end

  def state_up(), do: @state_up
  def state_degraded(), do: @state_degraded
  def state_issues(), do: @state_issues
  def state_down(), do: @state_down
  def state_blocked(), do: @state_blocked
  def state_unknown(), do: @state_unknown

  def states(), do: [state_up(), state_degraded(), state_blocked(), state_issues(), state_down(), state_unknown()]

  @weights %{
    :down => 4,
    :blocked => 3,
    :issues => 2,
    :degraded => 1,
    :up => 0
  }

  def get_worst_state(state1, state2) do
    weight1 = Map.get(@weights, state1, -1)
    weight2 = Map.get(@weights, state2, -1)
    if weight1 > weight2, do: state1, else: state2
  end

  def get_state_weight(state), do: @weights[state]
end
