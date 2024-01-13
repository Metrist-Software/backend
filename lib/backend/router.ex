defmodule Backend.Router do
  use Commanded.Commands.Router

  middleware Backend.EventStoreRewriter.Middleware
  middleware Domain.Middleware.TypeValidation

  # User routing
  identify Domain.User, by: :id
  dispatch [
    Domain.User.Commands.AcceptInvite,
    Domain.User.Commands.Create,
    Domain.User.Commands.CreateInvite,
    Domain.User.Commands.DeleteInvite,
    Domain.User.Commands.Login,
    Domain.User.Commands.Logout,
    Domain.User.Commands.MakeAdmin,
    Domain.User.Commands.RepealAdmin,
    Domain.User.Commands.SetReadOnly,
    Domain.User.Commands.Print,
    Domain.User.Commands.Update,
    Domain.User.Commands.UpdateAuth0Info,
    Domain.User.Commands.UpdateSlackDetails,
    Domain.User.Commands.SendMonitorSubscriptionReminder,
    Domain.User.Commands.ClearSubscriptionReminders,
    Domain.User.Commands.CreateHubspotContact,
    Domain.User.Commands.UpdateTimezone,
    Domain.User.Commands.UpdateEmail,
    Domain.User.Commands.DatadogLogin
  ], to: Domain.User

  # Account routing
  identify Domain.Account, by: :id
  dispatch [
    Domain.Account.Commands.AddAlertDeliveries,
    Domain.Account.Commands.AddAlerts,
    Domain.Account.Commands.AddAPIToken,
    Domain.Account.Commands.RemoveAPIToken,
    Domain.Account.Commands.RotateAPIToken,
    Domain.Account.Commands.AddMicrosoftTeamsCommand,
    Domain.Account.Commands.AddMonitor,
    Domain.Account.Commands.AddSlackSlashCommand,
    Domain.Account.Commands.AddSubscriptions,
    Domain.Account.Commands.AddUser,
    Domain.Account.Commands.AttachMicrosoftTenant,
    Domain.Account.Commands.AttachSlackWorkspace,
    Domain.Account.Commands.RemoveSlackWorkspace,
    Domain.Account.Commands.ChooseMonitors,
    Domain.Account.Commands.SetMonitors,
    Domain.Account.Commands.CompleteAlertDelivery,
    Domain.Account.Commands.DeleteSubscriptions,
    Domain.Account.Commands.MakeExternal,
    Domain.Account.Commands.MakeInternal,
    Domain.Account.Commands.Print,
    Domain.Account.Commands.RemoveUser,
    Domain.Account.Commands.UpdateName,
    Domain.Account.Commands.UpdateFreeTrial,
    Domain.Account.Commands.UpdateMicrosoftTenant,
    Domain.Account.Commands.AddSubscriptionDelivery,
    Domain.Account.Commands.AddSubscriptionDeliveryV2,
    Domain.Account.Commands.SetVisibleMonitors,
    Domain.Account.Commands.SetInstances,
    Domain.Account.Commands.AddInstance,
    Domain.Account.Commands.RemoveInstance,
    Domain.Account.Commands.AddVisibleMonitor,
    Domain.Account.Commands.RemoveVisibleMonitor,
    Domain.Account.Commands.SetStripeCustomerId,
    Domain.Account.Commands.CreateMembership,
    Domain.Account.Commands.StartMembershipIntent,
    Domain.Account.Commands.CompleteMembershipIntent,
    Domain.Account.Commands.DispatchAlert,
    Domain.Account.Commands.DropAlert
  ], to: Domain.Account

  dispatch [
    Domain.Account.Commands.Create
  ],
    to: Domain.Account,
    identity: :id,
    timeout: 10_000

  # SlackIntegration represents a process of a user attaching Slack to an account
  identify Domain.SlackIntegration, by: :id
  dispatch [
    Domain.SlackIntegration.Commands.CompleteConnection,
    Domain.SlackIntegration.Commands.FailConnection,
    Domain.SlackIntegration.Commands.RequestConnection
  ], to: Domain.SlackIntegration

  identify Domain.DatadogGrants, by: :id
  dispatch [
    Domain.DatadogGrants.Commands.RequestGrant,
    Domain.DatadogGrants.Commands.UpdateGrant
  ], to: Domain.DatadogGrants

  # Monitors
  identify Domain.Monitor, by: :id
  dispatch [
    Domain.Monitor.Commands.AddAnalyzerConfig,
    Domain.Monitor.Commands.AddConfig,
    Domain.Monitor.Commands.AddError,
    Domain.Monitor.Commands.AddEvent,
    Domain.Monitor.Commands.AddInstance,
    Domain.Monitor.Commands.AddTag,
    Domain.Monitor.Commands.AddTelemetry,
    Domain.Monitor.Commands.ChangeTag,
    Domain.Monitor.Commands.ClearEvents,
    Domain.Monitor.Commands.EndEvent,
    Domain.Monitor.Commands.Print,
    Domain.Monitor.Commands.RemoveTag,
    Domain.Monitor.Commands.Reset,
    Domain.Monitor.Commands.SetExtraConfig,
    Domain.Monitor.Commands.SetIntervalSecs,
    Domain.Monitor.Commands.SetRunGroups,
    Domain.Monitor.Commands.SetRunSpec,
    Domain.Monitor.Commands.SetSteps,
    Domain.Monitor.Commands.Create,
    Domain.Monitor.Commands.UpdateAnalyzerConfig,
    Domain.Monitor.Commands.UpdateCheckName,
    Domain.Monitor.Commands.InvalidateEvents,
    Domain.Monitor.Commands.InvalidateErrors,
    Domain.Monitor.Commands.UpdateInstance,
    Domain.Monitor.Commands.UpdateInstanceCheck,
    Domain.Monitor.Commands.UpdateLastReportTime,
    Domain.Monitor.Commands.RemoveCheck,
    Domain.Monitor.Commands.RemoveConfig,
    Domain.Monitor.Commands.ChangeName,
    Domain.Monitor.Commands.AddCheck,
    Domain.Monitor.Commands.SetTwitterHashtags,
    Domain.Monitor.Commands.AddTwitterCount,
    Domain.Monitor.Commands.RemoveInstance
  ], to: Domain.Monitor

  # StatusPage stuff
  identify Domain.StatusPage, by: :id
  dispatch [
    Domain.StatusPage.Commands.AddSubscription,
    Domain.StatusPage.Commands.Create,
    Domain.StatusPage.Commands.Remove,
    Domain.StatusPage.Commands.ProcessObservations,
    Domain.StatusPage.Commands.Reset,
    Domain.StatusPage.Commands.RemoveComponent,
    Domain.StatusPage.Commands.RemoveSubscription,
    Domain.StatusPage.Commands.RemoveComponentChanges,
    Domain.StatusPage.Commands.Print,
    Domain.StatusPage.Commands.SetSubscriptions
  ], to: Domain.StatusPage

  identify Domain.Notice, by: :id
  dispatch [
    Domain.Notice.Commands.Create,
    Domain.Notice.Commands.Update,
    Domain.Notice.Commands.Clear,
    Domain.Notice.Commands.MarkRead
  ], to: Domain.Notice

  # Keeping time
  identify Domain.Clock, by: :id
  dispatch [
    Domain.Clock.Tick
  ], to: Domain.Clock

  # Tracking (user) flows
  identify Domain.Flow, by: :id
  dispatch [
    Domain.Flow.Commands.Create,
    Domain.Flow.Commands.Step,
    Domain.Flow.Commands.Timeout
  ], to: Domain.Flow

  # Notification handling
  identify Domain.NotificationChannel, by: :id
  dispatch [
    Domain.NotificationChannel.Commands.QueueNotification,
    Domain.NotificationChannel.Commands.AttemptDelivery,
    Domain.NotificationChannel.Commands.CompleteDelivery,
    Domain.NotificationChannel.Commands.RetryDelivery,
    Domain.NotificationChannel.Commands.FailDelivery
  ], to: Domain.NotificationChannel

  identify Domain.IssueTracker, by: :id
  dispatch [
    Domain.Issue.Commands.EmitIssue,
    Domain.Issue.Commands.RemoveIssueSource
  ], to: Domain.IssueTracker
end
