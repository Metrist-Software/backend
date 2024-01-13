defmodule Domain.Issue.Commands do
  use TypedStruct

  typedstruct module: EmitIssue do
    use Domo

    field :id, String.t(), enforce: true
    field :account_id, String.t()
    field :state, Backend.RealTimeAnalytics.Snapshotting.state()
    field :source, Domain.IssueTracker.issue_source()
    field :source_id, String.t()
    field :service, String.t()

    # Monitor Events
    field :region, String.t()
    field :check_logical_name, String.t()

    # Status Page Events
    field :component_id, String.t()

    field :start_time, NaiveDateTime.t()
    field :end_time, NaiveDateTime.t()
  end

  typedstruct module: RemoveIssueSource do
    field :id, String.t(), enforce: true
    field :source, Domain.IssueTracker.issue_source()

    # Monitor Events
    field :check_logical_name, String.t()

    # Status Page Events
    field :component_id, String.t()

    field :time, NaiveDateTime.t()
  end
end
