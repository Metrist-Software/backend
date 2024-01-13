defmodule Backend.Projectors.AccountAnalytics do
  @moduledoc """
  This module runs analytics on account data. It collects the following:

  * Monitors: The count of monitors that are selected for an account.
  * Teams: True/false and count of subscriptions to indicate if the teams app is installed.
  * Slack: True/false, count of subscriptions to indicate if the slack chat app is installed, and count of
    slack alert notifications an account has received.
  * Users: Display the number of users registered for the account
  * WAU: Weekly active users for the specific account.
  * Last login: The count of days since a user has last logged into the web app.
  * Datadog: True/false count of subscriptions to indicate if the datadog integration is installed.
  * Email: Count of email subscriptions
  * Webhook: Count of webhook subscriptions.

  The idea is to start a task supervisor and then a task per data item, each
  subscribing to their own stream.

  Very much tbd until the TypeStreamLinker has run and we have Actual Data :)
  """
  require Logger
  import Ecto.Query

  use Backend.Projectors.TypeStreamLinker.Helpers
  alias Backend.Projections.Account

  def inc(multi, account_id, field_name), do: do_inc(multi, account_id, field_name, 1)
  def dec(multi, account_id, field_name), do: do_inc(multi, account_id, field_name, -1)

  defp do_inc(multi, account_id, field_name, step) do
    query =
      from a in Account,
        where: a.id == ^account_id,
        update: [inc: [{^field_name, ^step}]]

    Logger.info("Changing stat of #{account_id}, field: #{field_name}, by: #{step}")

    Ecto.Multi.update_all(multi, :update_counter, query, [])
  end

  # Note: these macro invocations generate modules, so calls to the stuff above
  # is actually cross-module.

  typed_ecto_handler(Domain.Account.Events.SubscriptionAdded, fn multi, event ->
    Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_subscriptions)
  end)

  typed_ecto_handler(Domain.Account.Events.SubscriptionDeleted, fn multi, event ->
    Backend.Projectors.AccountAnalytics.dec(multi, event.id, :stat_num_subscriptions)
  end)

  typed_ecto_handler(Domain.Account.Events.MonitorAdded, fn multi, event ->
    Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_monitors)
  end)

  typed_ecto_handler(Domain.Account.Events.MonitorRemoved, fn multi, event ->
    Backend.Projectors.AccountAnalytics.dec(multi, event.id, :stat_num_monitors)
  end)

  typed_ecto_handler(Domain.Account.Events.UserAdded, fn multi, event ->
    Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_users)
  end)

  typed_ecto_handler(Domain.Account.Events.UserRemoved, fn multi, event ->
    Backend.Projectors.AccountAnalytics.dec(multi, event.id, :stat_num_users)
  end)

  typed_ecto_handler(Domain.Account.Events.MicrosoftTenantAttached, fn multi, event ->
    Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_msteams)
  end)

  typed_ecto_handler(Domain.Account.Events.SlackWorkspaceAttached, fn multi, event ->
    Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_slack)
  end)

  typed_ecto_handler(Domain.Account.Events.SlackWorkspaceRemoved, fn multi, event ->
    Backend.Projectors.AccountAnalytics.dec(multi, event.id, :stat_num_slack)
  end)

  typed_ecto_handler(Domain.User.Events.LoggedIn, fn multi, event ->
    user = Backend.Projections.get_user!(event.id)
    if not is_nil(user.account_id) do

      # Maybe it is over the top to re-calculate WAU/MAU on every login, but for now
      # I think it's the simplest thing that can possibly work and the queries should
      # be quite fast.
      since = NaiveDateTime.utc_now() |> Timex.shift(weeks: -1)

      weekly_count =
        Backend.Projections.User
        |> where([u], u.account_id == ^user.account_id and u.last_login >= ^since)
        |> Backend.Repo.aggregate(:count)

      since = NaiveDateTime.utc_now() |> Timex.shift(days: -30)

      monthly_count =
        Backend.Projections.User
        |> where([u], u.account_id == ^user.account_id and u.last_login >= ^since)
        |> Backend.Repo.aggregate(:count)

      query =
        from a in Account,
          where: a.id == ^user.account_id,
          update: [
            set: [
              stat_last_user_login: ^event.timestamp,
              stat_weekly_users: ^weekly_count,
              stat_monthly_users: ^monthly_count
            ]
          ]

      Ecto.Multi.update_all(multi, :last_login, query, [])
    else
      multi
    end
  end)

  typed_ecto_handler(Domain.Account.Events.SubscriptionDeliveryAdded, fn multi, %{delivery_method: delivery_method} = event ->
    case delivery_method do
      "slack" -> Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_slack_alerts)
      _ -> multi
    end
  end)

  typed_ecto_handler(Domain.Account.Events.SlackSlashCommandAdded, fn multi, event ->
    Backend.Projectors.AccountAnalytics.inc(multi, event.id, :stat_num_slack_commands)
  end)
end
