defmodule Backend.Slack.SlackCommands do

  alias Backend.Slack.SlackBody
  alias Backend.Slack.SlashCommand
  alias Backend.Slack.SlackHelpers.SlackChannelHelper
  alias Backend.Projections
  alias Backend.RealTimeAnalytics
  require Logger

  ### execute ###

  def execute(%SlashCommand{text: "list"} = sc) do
    ordered_monitors =
      Projections.list_monitors(sc.account_id)
      |> Enum.sort_by(fn m -> m.name end, &<=/2)
    { monitors_with_snapshots, monitors_without_snapshots } =
    Enum.split_with(ordered_monitors,
    fn m ->
      has_snapshot?(m, sc.account_id)
    end)
    snapshot_list_or_monitor_selection(
      monitors_with_snapshots,
      monitors_without_snapshots,
      sc.account_id
      )
  end

  def execute(%SlashCommand{text: "help"} = _sc) do
    SlackBody.help()
  end

  def execute(%SlashCommand{text: ""} = sc) do
    Projections.list_monitors(sc.account_id)
    |> SlackBody.choose_monitor()
  end

  def execute(%SlashCommand{text: "notifications"} = sc) do
    case Projections.list_monitors(sc.account_id) do
      [] -> SlackBody.ask_user_to_perform_monitor_selection()
      monitors ->
        monitors
        |> Enum.sort_by(fn m -> m.name end, &<=/2)
        subscriptions =
          Projections.get_slack_subscriptions_for_account_and_identity(sc.account_id, sc.user_id)
        SlackBody.choose_notifications(monitors, subscriptions)
    end
  end

  def execute(%SlashCommand{text: << "subscriptions list", args::binary>>} = sc) do
    channel_id_and_name = args |> String.split(" ") |> Enum.at(1)
    should_list_all_channels? = (channel_id_and_name == nil) || (String.trim(channel_id_and_name) == "")
    SlackChannelHelper.is_channel_valid?(channel_id_and_name)
    |> maybe_list_subscriptions(
        sc,
        channel_id_and_name,
        should_list_all_channels?
      )
  end

  def execute(%SlashCommand{text: << "subscriptions ", args::binary>>} = sc) do
    channel_id_and_name = args |> String.split(" ") |> hd()
    SlackChannelHelper.is_channel_valid?(channel_id_and_name)
    |> maybe_choose_subscriptions(
      sc,
      channel_id_and_name
      )
  end

  def execute(sc) do
    args = String.split(sc.text, " ")
    monitor_logical_name = hd(args)
    {response, snapshot} =
      case RealTimeAnalytics.get_snapshot(sc.account_id, monitor_logical_name) do
        {:ok, nil} -> {:empty, nil}
        {:ok, snapshot} -> {:ok, snapshot}
        _ -> {:error, nil}
      end
    maybe_show_snapshot(
      response,
      snapshot,
      sc.account_id,
      sc.team_id,
      monitor_logical_name,
      Enum.at(args, 1) == "details"
      )
  end

  ### snapshot helpers ###

  def get_check_ids_order(account_id, monitor_logical_name) do
    monitor_configs_from_shared_and_account =
       Projections.get_monitor_configs_by_monitor_logical_name("SHARED", monitor_logical_name)
       ++ Projections.get_monitor_configs_by_monitor_logical_name(account_id, monitor_logical_name)

    case monitor_configs_from_shared_and_account do
      [] -> []
      [config | _] ->
        config.steps
        |> Enum.map(&(&1.check_logical_name))
        |> Enum.uniq()
    end
  end

  defp has_snapshot?(monitor, account_id) do
    case RealTimeAnalytics.get_snapshot(account_id, monitor.logical_name) do
      {:ok, snapshot} when not is_nil(snapshot) -> true
      _ -> false
    end
  end

  defp snapshot_list_or_monitor_selection(monitors_with_snapshots, monitors_without_snapshots, _account_id)
    when length(monitors_with_snapshots) == 0 and length(monitors_without_snapshots) == 0 do
      SlackBody.ask_user_to_perform_monitor_selection()
  end

  defp snapshot_list_or_monitor_selection(monitors_with_snapshots, monitors_without_snapshots, account_id) do
    snapshot_list =
      monitors_with_snapshots
      |> Enum.map(fn m ->
        {m, RealTimeAnalytics.get_snapshot(account_id, m.logical_name)} end)
      |> Enum.map(fn {m, {_response, snapshot}} ->
        {m, snapshot} end)
    SlackBody.list_snapshots(snapshot_list, monitors_without_snapshots)
  end

  defp maybe_show_snapshot(:ok, snapshot, account_id, team_id, monitor_logical_name, show_details) do
    monitor = Projections.get_monitor(account_id, monitor_logical_name)
    check_ids = get_check_ids_order(account_id, monitor_logical_name)
    SlackBody.snapshot(
      snapshot,
      monitor,
      [
        check_ids: check_ids,
        show_details: show_details,
        team_id: team_id
      ]
      )
  end

  defp maybe_show_snapshot(:empty, _snapshot, _account_id, _team_id, _monitor_logical_name, _show_details) do
    SlackBody.default("No data available.")
  end

  defp maybe_show_snapshot(:error, _snapshot, account_id, _team_id, _monitor_logical_name, _show_details) do
    monitor_not_found(account_id)
  end

  ### subscribe helpers ###

  defp maybe_choose_subscriptions(_valid_channel? = false, _sc, _channel_id_and_name) do
    channel_not_found_error()
  end

  defp maybe_choose_subscriptions( _valid_channel?, sc, channel_id_and_name) do
    {_channel_id, channel_name} = SlackChannelHelper.get_channel(channel_id_and_name)
    maybe_get_subscribe_channel_name(
      sc,
      channel_name
      )
  end

  defp maybe_get_subscribe_channel_name(_sc, _channel_name = nil) do
    channel_not_found_error()
  end

  defp maybe_get_subscribe_channel_name(sc, channel_name) do
    subscriptions =
      Projections.get_slack_subscriptions_for_account_and_identity(sc.account_id, channel_name)
    case Projections.list_monitors(sc.account_id) do
      [] -> SlackBody.ask_user_to_perform_monitor_selection()
      monitors -> monitors
        |> Enum.sort_by(fn m -> m.name end, &<=/2)
        |> SlackBody.choose_subscriptions(subscriptions, channel_name)
    end
  end

  ### list subscriptions helpers ###

  defp maybe_list_subscriptions(_valid_channel? = false, _sc, _channel_id_and_name, _should_list_all_channels? = false) do
    channel_not_found_error()
  end

  defp maybe_list_subscriptions(_valid_channel?, sc, channel_id_and_name, should_list_all_channels?) do
    get_all_subscriptions_or_subscriptions_by_channel(
      sc,
      channel_id_and_name,
      should_list_all_channels?
      )
  end

  defp get_all_subscriptions_or_subscriptions_by_channel(sc, _channel_id_and_name, _should_list_all_channels? = true) do
    monitors = Projections.list_monitors(sc.account_id)
    Projections.get_subscriptions_for_account(sc.account_id)
    |> Enum.filter(
      fn s ->
        s.delivery_method == "slack" && String.starts_with?(s.identity, "#")
      end)
    |> Enum.map(
      fn s ->
        {s, Enum.find(monitors, fn m -> s.monitor_id == m.logical_name end)}
      end)
    |> SlackBody.list_subscriptions()
  end

  defp get_all_subscriptions_or_subscriptions_by_channel(sc, channel_id_and_name, _should_list_all_channels? = false) do
    {_channel_id, channel_name} = SlackChannelHelper.get_channel(channel_id_and_name)  # already filtered out invalid channels
    maybe_get_list_channel_name(
      sc,
      channel_name
      )
  end

  defp maybe_get_list_channel_name(_sc, _channel_name = nil) do  # for private channels
  channel_not_found_error()
  end

  defp maybe_get_list_channel_name(sc, channel_name) do
    monitors = Projections.list_monitors(sc.account_id)
    Projections.get_slack_subscriptions_for_account_and_identity(sc.account_id, channel_name)
    |> Enum.map(
      fn s ->
        {s, Enum.find(monitors, fn m -> s.monitor_id == m.logical_name end)}
      end)
    |> SlackBody.list_subscriptions()
  end

  ### errors ###

  defp monitor_not_found(account_id) do
    Projections.list_monitors(account_id)
    |> SlackBody.monitor_not_found()
  end

  defp channel_not_found_error() do
    SlackBody.default("Channel not found.")
  end

end
