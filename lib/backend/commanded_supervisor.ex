defmodule Backend.CommandedSupervisor do
  @moduledoc """
  Supervises Commanded processes
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_arg) do
    children =
      [
        Backend.Projectors.TypeStreamLinker,
        Backend.Projectors.Ecto,
        Backend.Projectors.Telemetry,
        Backend.Projectors.TimescaleTelemetry,
        Backend.Projectors.Aggregate,

        Domain.Account.EventHandlers,
        Domain.User.EventHandlers,
        Domain.Monitor.EventHandlers,
        Backend.StatusPage.EventHandlers,
        Backend.Alerting.EventHandlers,
        Backend.Hubspot.EventHandlers,
        Domain.Processes.SlackIntegration,

        Domain.Flow.TimeoutProcess,
        Domain.Account.AlertManager,
        Domain.NotificationChannel.RetryProcess,
        Backend.Notifications.WebhookHandler,
        Backend.Notifications.SlackHandler,
        Backend.Notifications.DatadogHandler,
        Backend.Notifications.EmailHandler,
        Backend.Notifications.PagerDutyHandler,
        Domain.Issue.IssueManager
        | Backend.Projectors.AccountAnalytics.children()
      ]
      |> maybe_start_rta_event_handler()

    Supervisor.init(children,
      strategy: :one_for_one,
      # Allow each processes to be restarted 10 times in 10 seconds.
      # This will handle global proceesses which may be killed when a cluster forms
      max_restarts: length(children) * 10
    )
  end

  if Mix.env() == :test do
    def maybe_start_rta_event_handler(children) do
      children
    end
  else
    def maybe_start_rta_event_handler(children) do
      children ++ [Backend.RealTimeAnalytics.EventHandlers]
    end
  end
end
