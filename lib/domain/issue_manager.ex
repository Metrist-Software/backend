defmodule Domain.Issue.IssueManager do
  alias Domain.Issue.IssueManager
  alias Domain.Monitor.Events, as: MonitorEvents
  alias Domain.StatusPage.Events, as: StatusPageEvents
  alias Domain.Issue.Events, as: IssueEvents
  alias Domain.Issue.Commands, as: IssueCommands

  use TypedStruct

  use Commanded.ProcessManagers.ProcessManager,
    application: Backend.App,
    name: __MODULE__,
    start_from: :current,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  require Logger

  @derive Jason.Encoder
  defstruct [
    # Only used for testing
    :status
  ]

  def interested?(%StatusPageEvents.ComponentStatusChanged{} = event) do
    if status_page = status_page_by_id(event.id) do
      {:continue, to_process_uuid("SHARED", status_page.name)}
    else
      false
    end
  end

  def interested?(%StatusPageEvents.SubscriptionRemoved{} = event) do
    if status_page = status_page_by_id(event.id) do
      # It's not guaranteed that the process has started when a subscription is remomved
      # so we'll let it continue. In the handle/2 there's a pattern match to check if the status is :started
      # that will help us tell if the aggregate has already started
      {:continue, to_process_uuid(event.account_id, status_page.name)}
    else
      false
    end
  end

  def interested?(%MonitorEvents.EventAdded{} = event) do
    {:continue, to_process_uuid(event.account_id, event.monitor_logical_name)}
  end

  def interested?(%IssueEvents.IssueCreated{} = event) do
    process_uuid = to_process_uuid(event.account_id, event.service)
    {:continue, process_uuid}
  end

  def interested?(%IssueEvents.IssueEnded{} = event) do
    process_uuid = to_process_uuid(event.account_id, event.service)
    Logger.info("Issue process manager stopping for #{process_uuid}")
    {:stop, process_uuid}
  end

  def interested?(_), do: false

  def handle(%IssueManager{}, %StatusPageEvents.ComponentStatusChanged{} = event) do
    status_page = status_page_by_id(event.id)
    state = String.to_existing_atom(event.state)

    # Assume that the end time is now if a status page flips to :up
    end_time = if state == :up, do: NaiveDateTime.utc_now()

    account_ids_with_component_subscription(event.id, event.component_id)
    |> Enum.map(fn account_id ->
      %IssueCommands.EmitIssue{
        id: Domain.IssueTracker.id(account_id, status_page.name),
        account_id: account_id,
        state: state,
        component_id: event.component_id,
        region: event.instance,
        service: status_page.name,
        source: :status_page,
        source_id: event.change_id,
        start_time: event.changed_at,
        end_time: end_time
      }
    end)
  end

  def handle(%IssueManager{}, %MonitorEvents.EventAdded{} = event) do
    %IssueCommands.EmitIssue{
      id: Domain.IssueTracker.id(event.account_id, event.monitor_logical_name),
      account_id: event.account_id,
      state: String.to_existing_atom(event.state),
      start_time: event.start_time,
      end_time: event.end_time,
      region: event.instance_name,
      check_logical_name: event.check_logical_name,
      source: :monitor,
      source_id: event.event_id,
      service: event.monitor_logical_name
    }
  end

  def handle(
        %IssueManager{status: "issue_started"},
        %StatusPageEvents.SubscriptionRemoved{} = event
      ) do
    status_page = status_page_by_id(event.id)

    %IssueCommands.RemoveIssueSource{
      id: Domain.IssueTracker.id(event.account_id, status_page.name),
      source: :status_page,
      component_id: event.component_id,
      time: NaiveDateTime.utc_now()
    }
  end

  def apply(%IssueManager{} = manager, %IssueEvents.IssueCreated{}) do
    %IssueManager{manager | status: "issue_started"}
  end

  def status_page_by_id(status_page_id) do
    Backend.Projections.status_page_by_id("SHARED", status_page_id)
  end

  def account_ids_with_component_subscription(status_page_id, component_id) do
    # Note that this is expensive since it takes all the accounts
    # and checks if an account is subscribed to the component where the event came from
    # we need a better way to handle this
    {timing, account_ids} =
      :timer.tc(fn ->
        Backend.Projections.list_account_ids()
        |> Enum.filter(fn account_id ->
          Backend.Projections.account_subscribed_to_status_page_component?(
            account_id,
            status_page_id,
            component_id
          )
        end)
      end)

    Logger.debug("IssueManager: fetching account ids took: #{timing}us")
    account_ids
  end

  defp to_process_uuid(account_id, service) do
    "#{account_id}_#{service}"
  end
end
