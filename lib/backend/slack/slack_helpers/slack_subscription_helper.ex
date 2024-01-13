defmodule Backend.Slack.SlackHelpers.SlackSubscriptionHelper do

  alias Backend.Projections

  require Logger

  def set_subscriptions(user_id, channel_name, team_id, monitor_ids, display_name) do
    workspace = Projections.get_slack_workspace(team_id)
    existing_subscriptions =
    case channel_name do
      nil ->  # choosing personal notifications
        Projections.get_slack_subscriptions_for_account_and_identity(workspace.account_id, user_id)
      channel_name -> # choosing channel subscriptions
        Projections.get_slack_subscriptions_for_account_and_identity(workspace.account_id, channel_name)
    end

    to_add = Enum.filter(monitor_ids, fn m_id ->
      (Enum.find(existing_subscriptions, fn s -> s.monitor_id == m_id end)) == nil
    end)

    to_remove = Enum.filter(existing_subscriptions, fn s ->
      (Enum.find(monitor_ids, fn m_id -> m_id == s.monitor_id end)) == nil
    end)

    delete_command = %Domain.Account.Commands.DeleteSubscriptions{
      id: workspace.account_id,
      subscription_ids: Enum.map(to_remove, fn s -> s.id end)
    }

    new_subscriptions =
      Enum.map(to_add, fn monitor_id ->
        %Domain.Account.Commands.Subscription{
          subscription_id: Domain.Id.new(),
          monitor_id: monitor_id,
          delivery_method: "slack",
          identity: case channel_name do
            nil -> user_id
            channel_name -> channel_name
          end,
          regions: nil,
          display_name: display_name,
          extra_config: %{"WorkspaceId" => workspace.id}
        }
      end)

    add_command = %Domain.Account.Commands.AddSubscriptions{
      id: workspace.account_id,
      subscriptions: new_subscriptions
    }

    actor = Backend.Auth.Actor.slack(user_id, workspace.account_id)

    Backend.App.dispatch_with_actor(actor, add_command)
    Backend.App.dispatch_with_actor(actor, delete_command)
  end

end
