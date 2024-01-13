defmodule Domain.Issue.Events do
  use TypedStruct

  typedstruct module: IssueCreated do
    plugin(Backend.JsonUtils)

    field :id,         String.t(), enforce: true
    field :issue_id,   String.t()
    field :account_id, String.t()
    field :state,      String.t()
    field :source,     String.t()
    field :service,    String.t()
    field :start_time, NaiveDateTime.t()
  end

  typedstruct module: IssueEventAdded do
    plugin(Backend.JsonUtils)

    field :id,                 String.t(), enforce: true
    field :issue_id,           String.t()
    field :issue_event_id,     String.t()
    field :account_id,         String.t()
    field :state,              String.t()
    field :source,             String.t()
    field :source_id,          String.t()
    field :service,            String.t()

    # Monitor Events
    field :region,             String.t()
    field :check_logical_name, String.t()

    # Status Page Events
    field :component_id,       String.t()

    field :start_time, NaiveDateTime.t()
    field :end_time,           NaiveDateTime.t()
  end

  typedstruct module: IssueStateChanged do
    plugin(Backend.JsonUtils)

    field :id,          String.t(), enforce: true
    field :issue_id,    String.t()
    field :account_id,  String.t()
    field :worst_state, String.t()
  end

  typedstruct module: IssueEnded do
    plugin(Backend.JsonUtils)

    field :id,         String.t(), enforce: true
    field :issue_id,   String.t()
    field :service,    String.t()
    field :account_id, String.t()
    field :end_time,   NaiveDateTime.t()
  end

  typedstruct module: DistinctSourcesSet, enforce: true do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :issue_id, String.t()
    field :sources, list(String.t())
    field :account_id, String.t()
  end

  typedstruct module: IssueSourceRemoved do
    plugin(Backend.JsonUtils)
    field :id,     String.t(), enforce: true
    field :source, String.t()

    # Monitor Events
    field :check_logical_name, String.t()

    # Status Page Events
    field :component_id, String.t()
  end

end
