defmodule Domain.IssueTracker do
  @moduledoc """
  This aggregate is a long-term tracker of issues that happen to a certain account/service
  combination. Depending on events (which it mostly receives from its associate, the
  IssueManager process manager) it opens and closes issues and emits information about
  issue state changes.
  """

  use TypedStruct
  require Logger

  alias Domain.Issue.Commands
  alias Domain.Issue.Events
  alias Commanded.Aggregate.Multi
  alias Backend.RealTimeAnalytics.Snapshotting

  @type issue_source :: :status_page | :monitor
  @type status_page_component_id :: String.t()
  @type check_id :: String.t()
  @type source_key :: {issue_source(), status_page_component_id() | check_id()}

  typedstruct do
    field :id, String.t()
    field :current_issue_id, String.t()
    field :worst_state, Snapshotting.state()
    field :last_sources_state, %{source_key() => Snapshotting.state()}, default: %{}
    field :service, String.t()
    field :distinct_sources, list(issue_source()), default: []
    field :account_id, String.t()
    field :x_val, any()
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          "x_val" => Base.encode64(:erlang.term_to_binary(value))
        },
        opts
      )
    end
  end

  defimpl Commanded.Serialization.JsonDecoder do
    def decode(value) do
      :erlang.binary_to_term(Base.decode64!(value.x_val))
    end
  end

  def execute(%__MODULE__{current_issue_id: nil} = issue, c = %Commands.EmitIssue{})
    when c.state != :up do

    # normally, we would not want to generate a new key here but this is really just
    # a random number to correlate issue state updates, so this is the exception that
    # proves the rule for now.
    new_issue_id = Domain.Id.new()

    issue
    |> Multi.new()
    |> Multi.execute(fn _ ->
      %Events.IssueCreated{
        id: c.id,
        issue_id: new_issue_id,
        account_id: c.account_id,
        source: c.source,
        state: Atom.to_string(c.state),
        service: c.service,
        start_time: c.start_time
      }
    end)
    |> Multi.execute(fn _issue ->
      %Events.IssueEventAdded{
        id: c.id,
        issue_id: new_issue_id,
        issue_event_id: Domain.Id.new(),
        account_id: c.account_id,
        state: Atom.to_string(c.state),
        source: Atom.to_string(c.source),
        source_id: c.source_id,
        service: c.service,
        region: c.region,
        component_id: c.component_id,
        check_logical_name: c.check_logical_name,
        start_time: c.start_time,
        end_time: c.end_time
      }
    end)
  end

  def execute(%__MODULE__{current_issue_id: current_issue_id} = issue, c = %Commands.EmitIssue{})
    when current_issue_id != nil do

    # New information on an existing issue.

    previous_worst_state = issue.worst_state

    issue
    |> Multi.new()
    |> Multi.execute(fn _ ->
      %Events.IssueEventAdded{
        id: c.id,
        issue_id: current_issue_id,
        issue_event_id: Domain.Id.new(),
        account_id: c.account_id,
        state: Atom.to_string(c.state),
        source: Atom.to_string(c.source),
        source_id: c.source_id,
        service: c.service,
        region: c.region,
        component_id: c.component_id,
        check_logical_name: c.check_logical_name,
        start_time: c.start_time,
        end_time: c.end_time
      }
    end)
    |> Multi.execute(&check_distinct_sources_changed(&1))
    |> Multi.execute(&check_worst_state_changed(&1, previous_worst_state))
    |> Multi.execute(&check_issue_ended(&1, c.end_time))
  end

  def execute(%__MODULE__{}, %Commands.EmitIssue{}) do
    nil
  end

  def execute(%__MODULE__{ current_issue_id: nil }, %Commands.RemoveIssueSource{}), do: nil
  def execute(%__MODULE__{} = issue, c = %Commands.RemoveIssueSource{}) do
    issue
    |> Multi.new()
    |> Multi.execute(fn _ ->
      %Events.IssueSourceRemoved{
        id: c.id,
        source: Atom.to_string(c.source),
        check_logical_name: c.check_logical_name,
        component_id: c.component_id
      }
    end)
    |> Multi.execute(&check_distinct_sources_changed(&1))
    |> Multi.execute(&check_issue_ended(&1, c.time))
  end

  def apply(%__MODULE__{}, e = %Events.IssueCreated{}) do
    Logger.info(
      "Issue created for #{inspect(id: e.id, issue_id: e.issue_id, service: e.service, source: e.source)}"
    )

    state = String.to_existing_atom(e.state)

    %__MODULE__{
      id: e.id,
      current_issue_id: e.issue_id,
      account_id: e.account_id,
      worst_state: state,
      service: e.service,
      distinct_sources: [e.source]
    }
  end

  def apply(%__MODULE__{} = issue, e = %Events.IssueEventAdded{}) do
    state = String.to_existing_atom(e.state)
    source = String.to_existing_atom(e.source)

    worst_state =
      Backend.Projections.Dbpa.Snapshot.get_worst_state(
        issue.worst_state,
        state
      )

    last_sources_state =
      Map.update(
        issue.last_sources_state,
        source_key(source, e),
        state,
        fn _ -> state end
      )

    %__MODULE__{issue
      | worst_state: worst_state,
        last_sources_state: last_sources_state}
  end

  def apply(%__MODULE__{} = issue, %Events.IssueStateChanged{}) do
    issue
  end

  def apply(%__MODULE__{} = issue, %Events.DistinctSourcesSet{} = e) do
    %__MODULE__{issue | distinct_sources: Enum.map(e.sources, &String.to_existing_atom/1)}
  end

  def apply(%__MODULE__{} = issue, %Events.IssueSourceRemoved{} = e) do
    source = String.to_existing_atom(e.source)

    last_sources_state = Map.drop(issue.last_sources_state, [source_key(source, e)])

    %__MODULE__{issue | last_sources_state: last_sources_state}
  end

  def apply(%__MODULE__{} = issue, %Events.IssueEnded{}) do
    Logger.info(
      "Issue ended for #{inspect(id: issue.id, issue_id: issue.current_issue_id, service: issue.service, sources: issue.distinct_sources)}"
    )

    %__MODULE__{issue | current_issue_id: nil, worst_state: nil, last_sources_state: %{}}
  end

  def source_status_page, do: :status_page
  def source_monitor, do: :monitor

  defp check_distinct_sources_changed(%__MODULE__{} = issue) do
    current_distinct_sources = issue.last_sources_state
    |> Enum.map(fn {{source, _source_id}, _state} -> source end)
    |> MapSet.new()

    previous_distinct_sources = issue.distinct_sources
    |> MapSet.new()

    if current_distinct_sources != previous_distinct_sources do
      %Events.DistinctSourcesSet{
        id: issue.id,
        issue_id: issue.current_issue_id,
        sources: Enum.map(current_distinct_sources, &Atom.to_string/1),
        account_id: issue.account_id
      }
    else
      []
    end
  end

  defp check_worst_state_changed(%__MODULE__{} = issue, previous_worst_state)
       when issue.worst_state != previous_worst_state do
    %Events.IssueStateChanged{
      id: issue.id,
      issue_id: issue.current_issue_id,
      account_id: issue.account_id,
      worst_state: Atom.to_string(issue.worst_state)
    }
  end

  defp check_worst_state_changed(%__MODULE__{}, _previous_worst_state), do: []

  defp check_issue_ended(%__MODULE__{} = issue, last_event_dt) do
    if Map.values(issue.last_sources_state) |> Enum.all?(&(&1 == :up)) do
      %Events.IssueEnded{
        id: issue.id,
        issue_id: issue.current_issue_id,
        service: issue.service,
        account_id: issue.account_id,
        end_time: last_event_dt
      }
    else
      []
    end
  end

  def id(account_id, service) do
    "Issue_#{account_id}_#{service}"
  end

  def source_key(:monitor = source, %{check_logical_name: check_logical_name}) do
    {source, check_logical_name}
  end

  def source_key(:status_page = source, %{component_id: component_id}) do
    {source, component_id}
  end
end
