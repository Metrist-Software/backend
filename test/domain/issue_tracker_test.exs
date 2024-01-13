defmodule Domain.IssueTest do
  use ExUnit.Case, async: true
  alias Domain.Issue.Commands.{EmitIssue, RemoveIssueSource}
  alias Domain.IssueTracker
  alias Domain.Issue.Events, as: IssueEvents

  @account_id "account_id"
  @service_name "service"
  @check_logical_name "check"
  @check_logical_name2 "check"
  @component_id "component_id"
  @issue_aggregrate_id IssueTracker.id(@account_id, @service_name)

  test "execute/2 with EmitIssue when Issue id is nil returns IssueCreated and IssueEventAdded" do
    issue = %IssueTracker{id: @issue_aggregrate_id, current_issue_id: nil}

    {_state, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        source: IssueTracker.source_status_page(),
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert match?(
            [
              %IssueEvents.IssueCreated{id: @issue_aggregrate_id, issue_id: issue_id},
              %IssueEvents.IssueEventAdded{id: @issue_aggregrate_id, issue_id: issue_id}
            ],
            events
          )
  end

  test "execute/2 with EmitIssue when Issue id is present returns an IssueEventAdded" do
    issue = %IssueTracker{id: @issue_aggregrate_id, current_issue_id: "issue_id", worst_state: :down, distinct_sources: [IssueTracker.source_status_page()]}

    {_state, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :down,
        source: IssueTracker.source_status_page(),
        component_id: @component_id
      })
      |> IO.inspect()
      |> Commanded.Aggregate.Multi.run()

    assert match?(
            [%IssueEvents.IssueEventAdded{}],
            events
          )
  end

  test "execute/2 with EmitIssue updates the last_sources_state with the last command.state" do
    issue = %IssueTracker{id: @issue_aggregrate_id, current_issue_id: "issue_id", last_sources_state: %{}}

    {issue, _events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :down,
        source: IssueTracker.source_status_page(),
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    {issue, _events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :down,
        source: IssueTracker.source_monitor(),
        check_logical_name: @check_logical_name
      })
      |> Commanded.Aggregate.Multi.run()

    {issue, _events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :down,
        source: IssueTracker.source_monitor(),
        check_logical_name: @check_logical_name2
      })
      |> Commanded.Aggregate.Multi.run()

    assert issue.last_sources_state == %{
            {:status_page, @component_id} => :down,
            {:monitor, @check_logical_name2} => :down
          }
  end

  test "execute/2 with EmitIssue when command.state is worse than issue.state, updates the issue.state" do
    issue = %IssueTracker{id: @issue_aggregrate_id, current_issue_id: "issue_id", worst_state: :degraded}

    {state, _events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :down,
        source: :monitor,
        check_logical_name: @check_logical_name
      })
      |> Commanded.Aggregate.Multi.run()

    assert state.worst_state == :down
  end

  test "execute/2 with EmitIssue when all sources are :up, Emits an IssueEnded event and resets the aggregate state" do
    issue = %IssueTracker{id: @issue_aggregrate_id, current_issue_id: "issue_id", worst_state: :down, distinct_sources: []}

    # Down events

    {issue, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :degraded,
        source: :monitor,
        check_logical_name: @check_logical_name
      })
      |> Commanded.Aggregate.Multi.run()

    assert match?([%IssueEvents.IssueEventAdded{} | _], events)

    {issue, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :degraded,
        source: :status_page,
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert issue.last_sources_state == %{
            {:monitor, @check_logical_name} => :degraded,
            {:status_page, @component_id} => :degraded
          }

    assert match?([%IssueEvents.IssueEventAdded{} | _], events)

    # Up events

    {issue, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :up,
        source: :monitor,
        check_logical_name: @check_logical_name
      })
      |> Commanded.Aggregate.Multi.run()

    assert issue.last_sources_state == %{
            {:monitor, @check_logical_name} => :up,
            {:status_page, @component_id} => :degraded
          }

    assert match?([%IssueEvents.IssueEventAdded{}], events)

    {issue, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :up,
        source: :status_page,
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert match?([%IssueEvents.IssueEventAdded{}, %IssueEvents.IssueEnded{}], events)

    # Aggregate state reset

    assert match?(
            %IssueTracker{
              current_issue_id: nil,
              worst_state: nil,
              last_sources_state: %{}
            },
            issue
          )
  end

  test "execute/2 with RemoveIssueSource removes the issue source" do
    issue = %IssueTracker{
      id: @issue_aggregrate_id,
      current_issue_id: "issue_id",
      worst_state: :down,
      last_sources_state: %{
        {:monitor, @check_logical_name} => :down,
        {:status_page, @component_id} => :down
      }
    }

    {issue, events} =
      IssueTracker.execute(issue, %RemoveIssueSource{
        id: @issue_aggregrate_id,
        source: :status_page,
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert Map.get(issue.last_sources_state, {:status_page, @component_id}) == nil
    assert match?([%IssueEvents.IssueSourceRemoved{} | _], events)
  end

  test "execute/2 with RemoveIssueSource does not do anything when there is no current issue" do
    # Most likely this caused MET-1276. If there's no current issue, we don't need to change anything,
    # a new issue will start with a clean slate.
    issue = %IssueTracker{
      id: @issue_aggregrate_id,
      current_issue_id: nil,
      worst_state: :down,
      last_sources_state: %{
        {:monitor, @check_logical_name} => :down,
        {:status_page, @component_id} => :down
      }
    }

    events =
      IssueTracker.execute(issue, %RemoveIssueSource{
        id: @issue_aggregrate_id,
        source: :status_page,
        component_id: @component_id
      })

    assert is_nil(events)
  end

  test "execute/2 with RemoveIssueSource ends issue if all sources are up" do
    issue = %IssueTracker{
      id: @issue_aggregrate_id,
      current_issue_id: "issue_id",
      worst_state: :down,
      last_sources_state: %{
        {:monitor, @check_logical_name} => :up,
        {:status_page, @component_id} => :down
      },
      distinct_sources: [:monitor, :status_page]
    }

    {issue, events} =
      IssueTracker.execute(issue, %RemoveIssueSource{
        id: @issue_aggregrate_id,
        source: :status_page,
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert Map.get(issue.last_sources_state, {:status_page, @component_id}) == nil
    assert match?([%IssueEvents.IssueSourceRemoved{}, %IssueEvents.DistinctSourcesSet{}, %IssueEvents.IssueEnded{}], events)
  end

  test "execute/2 with a new issue source adds to distinct issues" do
    issue = %IssueTracker{
      id: @issue_aggregrate_id,
      current_issue_id: "issue_id",
      worst_state: :down,
      last_sources_state: %{{:monitor, @check_logical_name} => :down},
      distinct_sources: [:monitor]
    }

    {issue, events} =
      IssueTracker.execute(issue, %EmitIssue{
        id: @issue_aggregrate_id,
        account_id: @account_id,
        state: :down,
        source: :status_page,
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert match?([%IssueEvents.IssueEventAdded{}, %IssueEvents.DistinctSourcesSet{}], events)
    assert match?(
      %IssueTracker{
        distinct_sources: [:monitor, :status_page]
      },
      issue
    )
  end

  test "execute/2 removing an issue source also removes it from distinct issues" do
    issue = %IssueTracker{
      id: @issue_aggregrate_id,
      current_issue_id: "issue_id",
      worst_state: :down,
      last_sources_state: %{
        {:monitor, @check_logical_name} => :down,
        {:status_page, @component_id} => :down
      },
      distinct_sources: [:monitor, :status_page]
    }

    {issue, events} =
      IssueTracker.execute(issue, %RemoveIssueSource{
        id: @issue_aggregrate_id,
        source: :status_page,
        component_id: @component_id
      })
      |> Commanded.Aggregate.Multi.run()

    assert match?([%IssueEvents.IssueSourceRemoved{}, %IssueEvents.DistinctSourcesSet{}], events)
    assert match?(
      %IssueTracker{
        distinct_sources: [:monitor]
      },
      issue
    )
  end
end
