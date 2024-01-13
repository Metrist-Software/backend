defmodule Backend.Slack.SlackInteractionHandler do

  alias Backend.Projections
  alias Backend.Slack.SlackBody
  alias Backend.Slack.SlackCommands
  alias Backend.RealTimeAnalytics
  alias Backend.Slack.SlackHelpers.SlackSubscriptionHelper
  alias Backend.Slack.SlackInteractionHandler

  use TypedStruct
  require Logger

  typedstruct module: SlackInteraction, enforce: true do
    @derive Jason.Encoder
    field :action, String.t()
    field :action_type, String.t()
    field :account_id, String.t()
    field :type, String.t()
    field :response_url, String.t()
    field :actions, list(SlackInteractionHandler.SlackInteractionAction.t())
    field :user, SlackInteractionHandler.SlackUser.t()
  end

  typedstruct module: SlackUser, enforce: true do
    @derive Jason.Encoder
    field :id, String.t()
    field :username, String.t()
    field :name, String.t()
    field :team_id, String.t()
  end

  typedstruct module: SlackInteractionAction, enforce: true do
    @derive Jason.Encoder
    field :type, String.t()
    field :action_id, String.t()
    field :selected_option, SlackInteractionHandler.SlackInteractionOption.t()
    field :selected_options, list(SlackInteractionHandler.SlackInteractionOption.t())
    field :value, String.t()
  end

  typedstruct module: SlackInteractionOption, enforce: true do
    @derive Jason.Encoder
    field :text, SlackInteractionHandler.SlackInteractionOptionText.t()
    field :value, String.t()
  end

  typedstruct module: SlackInteractionOptionText, enforce: true do
    @derive Jason.Encoder
    field :type, String.t()
    field :text, String.t()
    field :emoji, boolean
  end

  ### execute ###

  def execute(%SlackInteraction{action_type: "choose-monitor"} = interaction) do
    monitor_logical_name = interaction.action.selected_option.value

    {response, snapshot} =
    case RealTimeAnalytics.get_snapshot(interaction.account_id, monitor_logical_name) do
      {:ok, nil} -> {:empty, nil}
      {:ok, snapshot} -> {:ok, snapshot}
      _ -> {:error, nil}
    end

    maybe_show_snapshot(response, snapshot, interaction.account_id, interaction.user.team_id)
  end

  def execute(%SlackInteraction{action_type: "choose-notifications"} = interaction) do
    monitor_ids =
      interaction.action.selected_options
      |> Enum.map(fn o -> o.value end)
      |> Enum.to_list

    SlackSubscriptionHelper.set_subscriptions(
      interaction.user.id,
      nil, # channel name not required
      interaction.user.team_id,
      monitor_ids,
      interaction.user.name
      )
    SlackBody.notifications_response()
  end

  def execute(%SlackInteraction{action_type: "choose-subscriptions"} = interaction) do
    split_action_id = String.split(interaction.action.action_id, " ")

    maybe_choose_subscriptions(
      split_action_id,
      interaction.action,
      interaction.user.team_id,
      interaction.user.id
      )
  end

  def execute(%SlackInteraction{action_type: "show-details"} = interaction) do
    monitor_logical_name = hd(interaction.actions).value
    {status, snapshot} = RealTimeAnalytics.get_snapshot(
      interaction.account_id,
      monitor_logical_name
      )
    check_ids = SlackCommands.get_check_ids_order(interaction.account_id, monitor_logical_name)

    case status do
      :ok ->
        monitor =
          Projections.get_monitor(
            interaction.account_id,
            snapshot.monitor_id
            )
        SlackBody.snapshot(
          snapshot,
          monitor,
          [
            show_details: true,
            check_ids: check_ids,
            team_id: interaction.user.team_id
          ]
          )
      _ -> SlackBody.default()
    end
  end

  def execute(%SlackInteraction{action_type: "show-monitor"} = interaction) do
    Logger.debug("Explore button invoked using team_id #{interaction.user.team_id}. Slack user: #{inspect interaction.user, pretty: true}")
  end

  def execute(_default) do
    SlackBody.default()
  end

  ### helpers ###

  defp maybe_choose_subscriptions(split_action_id, action, team_id, user_id) when length(split_action_id) == 2 do
    channel_name = Enum.at(split_action_id, 1)
    monitor_ids =
      action.selected_options
      |> Enum.map(fn o -> o.value end)
      |> Enum.to_list()

    SlackSubscriptionHelper.set_subscriptions(
      user_id,
      channel_name,
      team_id,
      monitor_ids,
      channel_name
      )
    SlackBody.subscribe_response(channel_name)
  end

  defp maybe_choose_subscriptions(_split_action_id, action, _team_id, _user_id) do
    SlackBody.default("Error - Invalid Action ID for choose-subscription: #{action.action_id}")
  end

  defp maybe_show_snapshot(:ok, snapshot, account_id, team_id) do
    check_ids = SlackCommands.get_check_ids_order(account_id, snapshot.monitor_id)
    SlackBody.snapshot(
      snapshot,
      Projections.get_monitor(account_id, snapshot.monitor_id),
      [
        show_details: false,
        check_ids: check_ids,
        team_id: team_id
      ]
      )
  end

  defp maybe_show_snapshot(:empty, _snapshot, _account_id, _team_id) do
    SlackBody.default("No data available.")
  end

  defp maybe_show_snapshot(:error, _snapshot, _account_id, _team_id) do
    SlackBody.default()
  end

end
