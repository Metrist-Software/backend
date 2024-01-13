defmodule Backend.Slack.SlackBody do

  alias Backend.Projections.Dbpa.Monitor
  alias Backend.Projections.Dbpa.Snapshot
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail

  require Logger

  @block_cutoff_count 45
  @select_cutoff_count 100
  @check_instance_cutoff_count 10
  @divider_block %{type: "divider"}

  ### choose monitors ###

  def choose_monitor(monitors) do
    maybe_choose_monitor(monitors)
  end

  defp maybe_choose_monitor(_monitors = nil) do
    ask_user_to_perform_monitor_selection()
  end

  defp maybe_choose_monitor(_monitors = []) do
    ask_user_to_perform_monitor_selection()
  end

  defp maybe_choose_monitor(monitors) do
    ordered_monitors = Enum.sort_by(monitors, fn m -> String.downcase(m.name) end, &<=/2)
    %{
      response_type: "ephemeral",
      blocks: [
        %{
          type: "section",
          text: text_block("Which service would you like to know about?", type: "mrkdwn"),
          accessory: %{
                      type: "static_select",
                      placeholder: text_block("Select a service", emoji: true),
                      options:
                        ordered_monitors
                        |> Enum.take(@select_cutoff_count)
                        |> Enum.map(fn m ->
                          %{
                            text: text_block("#{m.name} (#{m.logical_name})", emoji: true),
                            value: m.logical_name
                          }
                        end),
                      action_id: "choose-monitor"
          }
        }
      ]
    }
  end

  def ask_user_to_perform_monitor_selection do
    path = BackendWeb.Router.Helpers.redirect_url(BackendWeb.Endpoint, :index)
    %{
      response_type: "ephemeral",
      blocks: [
        %{
          type: "section",
          text: text_block("""
          *You have no dependencies selected in your account*.\n\n \
          To enable interaction through Slack, please go to the <#{path}|Monitors section> in our web UI and click the \"Manage\" button. \
          Once you have selected the services that are of interest to your organization, you can return here and interact with Metrist through Slack.
          """, type: "mrkdwn")
        }
      ]
    }
  end

  ### list subscriptions ###

  def list_subscriptions(subscription_list) do
    path = BackendWeb.Router.Helpers.live_url(BackendWeb.Endpoint, BackendWeb.MonitorAlertingLive)
    valid_subs =
      subscription_list
      |> Enum.count(fn {subscription, monitor} ->
        subscription.identity != nil && monitor.name != nil
      end)
    error = [
      %{
        type: "section",
        text: text_block("Sorry, we can't display all of your subscriptions. <#{path}|Click here to view them all.>", type: "mrkdwn")
      }
    ]
    maybe_list_subscriptions(
      valid_subs,
      subscription_list,
      error
      )
  end

  defp maybe_add_error_message(blocks, num_blocks, error) when num_blocks > @block_cutoff_count do
    blocks ++ error
  end

  defp maybe_add_error_message(blocks, _num_blocks, _error) do
    blocks
  end

  defp maybe_list_subscriptions(valid_subs, subscription_list, error) when valid_subs > 0 do
    num_blocks = Enum.count(subscription_list)
    valid_subs_list =
      subscription_list
      |> Enum.filter(fn {subscription, monitor} -> subscription.identity != nil && monitor.name != nil end)
      |> Enum.take(@block_cutoff_count)

    %{
      response_type: "in_channel",
      blocks: Enum.map(valid_subs_list, fn {s, m} ->
        %{
          type: "section",
          text: text_block("🔔 #{m.name} in #{s.display_name}", type: "mrkdwn")
        }
      end)
      |> maybe_add_error_message(num_blocks, error)
    }
  end

  defp maybe_list_subscriptions(_valid_subs, _subscription_list, _error) do
    %{
      response_type: "ephemeral",
      blocks: [
        %{
          type: "section",
          text: text_block("""
          No subscriptions found. \
          You can use `/metrist subscriptions <Channel Name>` or `/metrist notifications` to setup monitor subscriptions.
          """, type: "mrkdwn")
      }
    ]
  }
  end

  def choose_subscriptions(monitors, existing_subscriptions, channel_name) do
    choose_subscriptions_or_notifications(monitors, existing_subscriptions, channel_name)
  end

  def choose_notifications(monitors, existing_subscriptions) do
    choose_subscriptions_or_notifications(monitors, existing_subscriptions, nil)
  end

  # Channel name is nil for choose_notifications only
  defp choose_subscriptions_or_notifications(monitors, existing_subscriptions, channel_name) do
    ordered_monitors =
      Enum.sort_by(monitors, fn m -> String.downcase(m.name) end, &<=/2)
      |> Enum.take(@select_cutoff_count)

    monitor_id_to_name_mapping =
      Enum.reduce(ordered_monitors, %{}, fn m, monitor_id_to_name_mapping ->
        Map.put(
          monitor_id_to_name_mapping,
          m.logical_name,
          m.name)
        end)
    %{
      response_type: "ephemeral",
      blocks: [
        %{
          type: "section",
          text: case channel_name do
            nil -> text_block("Click to select which monitors will send you notifications.", emoji: true)
            _ -> text_block("Click to select which monitors will send #{channel_name} notifications.", type: "mrkdwn")
          end,
            accessory: maybe_initial_options(
            ordered_monitors,
            existing_subscriptions,
            monitor_id_to_name_mapping,
            case channel_name do
              nil -> "choose-notifications"
              _ -> "choose-subscriptions #{channel_name}"
            end
            )
        }
      ]
      }
  end

  defp maybe_initial_options(monitors, existing_subscriptions, _monitor_id_to_name_mapping, action_id)
    when length(existing_subscriptions) == 0 do
    %{
      type: "multi_static_select",
      action_id: action_id,
      placeholder: text_block("Select your monitors", emoji: true),
      options:
        monitors
        |> Enum.map(fn m ->
          %{
            text: text_block(m.name, emoji: true),
            value: m.logical_name
          }
        end)
    }
  end

  defp maybe_initial_options(monitors, existing_subscriptions, monitor_id_to_name_mapping, action_id) do
    %{
      type: "multi_static_select",
      action_id: action_id,
      initial_options: existing_subscriptions
      |> Enum.filter(fn s ->
        Map.has_key?(monitor_id_to_name_mapping, s.monitor_id)
      end)
      |> Enum.map(fn s ->
        %{
          text: text_block(monitor_id_to_name_mapping[s.monitor_id], emoji: true),
          value: s.monitor_id
        }
      end),
      placeholder: text_block("Select your monitors", emoji: true),
      options:
        monitors
        |> Enum.map(fn m ->
          %{
            text: text_block(m.name, emoji: true),
            value: m.logical_name
          }
        end)
    }
  end

  ### snapshot ###

  def snapshot(snapshot, monitor, opts \\ []) do
    default_opts = [
      now: NaiveDateTime.utc_now,
      show_details: false,
      blocks_only: false,
      check_ids: [],
      team_id: "--TEAM_ID--"
    ]

    opts = []
    |> Keyword.merge(default_opts)
    |> Keyword.merge(opts)

    now = opts[:now]
    show_details = opts[:show_details]
    blocks_only = opts[:blocks_only]
    team_id = opts[:team_id]
    # checks not in the list passed will be added to the end
    check_ids = case opts[:check_ids] do
      [] -> get_check_ids_order_by_check_details(snapshot.check_details)
      check_ids ->
        check_ids ++ get_check_ids_order_by_check_details(snapshot.check_details)
        |> Enum.uniq
    end

    monitor_name = get_monitor_name(monitor, snapshot)

    logical_name = case monitor do
      nil -> get_monitor_name(nil, snapshot)
      _ -> monitor.logical_name
    end

    show_details_string = case show_details do
      true -> " details"
      _ -> ""
    end

    header = make_snapshot_header(
      snapshot,
      monitor_name,
      logical_name,
      show_details_string
      )

    {details, grouped_check_details} =
      maybe_get_details(
        snapshot,
        check_ids,
        show_details,
        now
      )

    status_page_check_details_filter_fn =
      if show_details do
        fn _cd -> true end
      else
        fn cd -> cd.state not in [:blocked, :up] end
      end

    details =
      details
      |> add_status_page_component_blocks(
          snapshot.status_page_component_check_details,
          monitor_name: monitor_name,
          check_details_filter_fn: status_page_check_details_filter_fn
        )
      |> maybe_add_cutoff_exceeded_message(
          snapshot,
          grouped_check_details,
          monitor,
          status_page_check_details_filter_fn
        )

    footer =
      [make_action_button(logical_name, [slack_team_id: team_id, show_details: show_details])]
      |> maybe_metrist_last_checked(snapshot)

    footer = case Enum.member?(details, @divider_block) do
      true -> footer
      _ -> [@divider_block | footer]
    end

    maybe_add_response_type(
      blocks_only,
      header ++ details ++ footer
      )
  end

  defp maybe_add_cutoff_exceeded_message(details, snapshot, grouped_check_details, monitor, status_page_check_details_filter_fn) do
    if check_instance_cutoff_exceeded?(
      snapshot.status_page_component_check_details,
      grouped_check_details,
      @check_instance_cutoff_count,
      status_page_check_details_filter_fn
    ) do
    path = BackendWeb.Router.Helpers.redirect_url(BackendWeb.Endpoint, :index)

    details ++
      [
        %{
          text:
            text_block(
              "Some check instances are hidden. <#{path}/#{monitor.logical_name}|View all instances>",
              type: "mrkdwn"
            ),
          type: "section"
        }
      ]
    else
      details
    end
  end

  defp maybe_get_details(%Snapshot.Snapshot{check_details: []}, _check_ids, _show_details, _now) do
    {_evaluated_blocks = [], _grouped_check_details = []}
  end

  defp maybe_get_details(snapshot, check_ids, show_details, now) do
    {filtered_check_details, filtered_check_ids} =
      filter_check_details_and_check_ids(
        snapshot,
        show_details,
        check_ids
        )

    grouped_check_details = filtered_check_details
    |> Enum.group_by(fn detail -> detail.check_id end)

    evaluated_blocks =
      grouped_check_details
      |> arrange_check_details_into_correct_order(filtered_check_ids)
      |> Enum.flat_map(fn check_details ->
        check_name = case List.first(check_details) do
          %{name: nil, check_id: check_id} ->
            check_id
          %{name: name} ->
            name
        end

        header = %{
          type: "section",
          text: text_block("*#{check_name}*", type: "mrkdwn")
        }

        checks = get_checks(check_details, now)

        inner_details = %{
          type: "context",
          elements: checks
        }

        [header, inner_details, @divider_block]
      end)

    {evaluated_blocks, grouped_check_details}
  end

  defp arrange_check_details_into_correct_order(groups, _check_ids) when groups == %{} do
    []
  end

  defp arrange_check_details_into_correct_order(groups, check_ids) do
    Enum.map(check_ids, fn check_id ->
      if check_details = Map.get(groups, check_id) do
         check_details
      else
        [
          %CheckDetail{
            name: check_id,
            check_id: check_id,
            state: :empty
          }
        ]
      end
    end)
  end

  defp filter_check_ids_by_present_check_details(filtered_check_details, check_ids) do
    filtered_check_details_ids = Enum.into(filtered_check_details, MapSet.new(), & &1.check_id)
    Enum.filter(check_ids, &MapSet.member?(filtered_check_details_ids, &1))
  end

  defp filter_check_details_and_check_ids(%Snapshot.Snapshot{state: :up} = _snapshot, _show_details = false, check_ids) do
    {[], check_ids}
  end

  defp filter_check_details_and_check_ids(snapshot, _show_details = true, check_ids) do
    {snapshot.check_details, check_ids}
  end

  defp filter_check_details_and_check_ids(snapshot, _show_details = false, check_ids) do
    filtered_check_details =
      snapshot.check_details
      |> Enum.reject(& &1.state == :blocked)
      |> Enum.reject(& &1.state == :up)
    filtered_check_ids =
      filter_check_ids_by_present_check_details(filtered_check_details, check_ids)

    {filtered_check_details, filtered_check_ids}
  end

  defp show_message_or_timing(%CheckDetail{state: :up} = detail) do
    " *#{round(detail.current)}ms* _(#{Float.round(detail.average, 1)}ms avg)_ "
  end

  defp show_message_or_timing(%CheckDetail{state: _} = detail) do
    " *#{detail.message}* "
  end

  defp get_check_ids_order_by_check_details(check_details_list) do
    check_details_list
    |> Enum.into([], fn detail -> detail.check_id end)
    |> Enum.uniq
  end

  defp get_checks(check_details, now) do
    # Bubble most serious states to the top before cut off
    Enum.sort(check_details, fn left, right ->
      if left.state == right.state do
        left.instance <= right.instance
      else
        Snapshot.get_state_weight(left.state) >= Snapshot.get_state_weight(right.state)
      end
    end)
    |> Enum.take(@check_instance_cutoff_count)
    |> Enum.map(fn detail ->
      case detail.state do
        :empty ->
          text_block("No data available", type: "mrkdwn")
        _->
          last_check_time = NaiveDateTime.diff(now, detail.last_checked)
          check_message = show_message_or_timing(detail)
          text_block("#{check_emoji(detail.state)} [#{detail.instance}]" <> check_message <> "⏱ *#{last_check_time}* seconds ago", type: "mrkdwn")
      end
    end)
  end

  defp get_monitor_name(_monitor = nil, snapshot) do
    snapshot.monitor_id
  end

  defp get_monitor_name(monitor, _snapshot) do
    monitor.name
  end

  defp maybe_add_response_type(_blocks_only = true, blocks) do
    %{ blocks: blocks }
  end

  defp maybe_add_response_type(_blocks_only, blocks) do
    %{
      response_type: "in_channel",
      blocks: blocks
    }
  end

  defp make_alert_header(snapshot, monitor_name, logical_name) do
    header_state = Backend.RealTimeAnalytics.Snapshotting.notification_header_state(snapshot)

    text_block =
      cond do
        Enum.any?(snapshot.status_page_component_check_details, &((&1.state != :up))) and
        Enum.any?(snapshot.check_details, &((&1.state != :up))) ->
          text_block("#{check_emoji(header_state)} #{monitor_name} is experiencing some issues: #{state_text(header_state)}.", [emoji: true])
        Enum.any?(snapshot.status_page_component_check_details, &((&1.state != :up))) ->
          text_block("#{status_emoji(header_state)} #{monitor_name} just updated their status page: #{state_text(header_state)}.", [emoji: true])
        true ->
          text_block("#{monitor_emoji(header_state)} #{monitor_name} is #{state_text(header_state)}.", [emoji: true])
      end

      [
        %{
          type: "header",
          text: text_block
        },
        %{
          type: "context",
          elements: [text_block("/metrist #{logical_name}")]
        }
      ]
  end

  defp make_snapshot_header(snapshot, monitor_name, logical_name, show_details_string) do
    # Show a issues message if one status page component is not healthy
    header_state = Backend.RealTimeAnalytics.Snapshotting.notification_header_state(snapshot)

    [
      %{
        type: "header",
        text: text_block("#{monitor_emoji(header_state)} #{monitor_name} is #{state_text(header_state)}.", [emoji: true])
      },
      %{
        type: "context",
        elements: [text_block("/metrist #{logical_name}#{show_details_string}")]
      }
    ]
  end

  defp make_action_button(monitor_logical_name, opts) do
    default_opts = [
      show_details: false,
      show_expand_button: true,
      slack_team_id: "--TEAM_ID--",
    ]

    opts = Keyword.merge(default_opts, opts)

    show_details = opts[:show_details]
    show_expand_button = opts[:show_expand_button]
    slack_team_id = opts[:slack_team_id]

    url = BackendWeb.Router.Helpers.slack_login_url(BackendWeb.Endpoint, :slack_login, slack_team_id, monitor_logical_name)

    explore_button = %{
      type: "button",
      text: text_block("→ Explore", [emoji: true]),
      value: monitor_logical_name,
      url: url,
      action_id: "show-monitor"
    }

    expand_button = %{
      type: "button",
      text: text_block("➕ Expand", [emoji: true]),
      value: monitor_logical_name,
      action_id: "show-details"
    }

    %{
      type: "actions",
      elements:
        if show_details == false and show_expand_button == true do
          [expand_button, explore_button]
        else
          [explore_button]
        end
      }

  end

  def list_snapshots(snapshot_list, monitors_without_snapshots) do
    path = BackendWeb.Router.Helpers.redirect_url(BackendWeb.Endpoint, :index)
    snapshots =
      snapshot_list
      |> Enum.sort_by(fn {_monitor, snapshot} -> String.downcase(snapshot.monitor_id) end, &<=/2)
      |> Enum.take(@block_cutoff_count)
      |> Enum.map(fn {%Monitor{name: monitor_name}, %Snapshot.Snapshot{state: snapshot_state}} ->
        %{
          type: "section",
          text: text_block("#{monitor_emoji(snapshot_state)} #{monitor_name} is #{state_text(snapshot_state)}.", type: "mrkdwn")
          }
        end)

    body = %{
              response_type: "in_channel",
              blocks: snapshots ++ maybe_display_no_data_available(snapshots, monitors_without_snapshots)
    }
    error = [
      %{
        type: "section",
        text: text_block("Sorry, we can't display all of your monitors. <#{path}|Click here to view them all.>", type: "mrkdwn")
      }
    ]

    maybe_add_error_to_body(
      snapshot_list,
      body,
      error
      )
  end

  defp maybe_display_no_data_available(snapshots, _monitors_without_snapshots) when (length(snapshots) - @block_cutoff_count) == 0 do
    []
  end

  defp maybe_display_no_data_available(snapshots, monitors_without_snapshots) do
    blocks_left = length(snapshots) - @block_cutoff_count
    monitors_without_snapshots
    |> Enum.sort_by(fn m -> String.downcase(m.name) end, &<=/2)
    |> Enum.take(blocks_left)
    |> Enum.map(fn %Monitor{name: monitor_name} ->
      %{
        type: "section",
        text: text_block("#{monitor_name}: no data available.", type: "mrkdwn")
        }
      end)
  end

  defp maybe_add_error_to_body(snapshot_list, body, error) when length(snapshot_list) > @block_cutoff_count do
    %{
      response_type: "in_channel",
      blocks: body.blocks ++ error
    }
  end

  defp maybe_add_error_to_body(_snapshot_list, body, _error) do
    body
  end

  ### responses ###

  def subscribe_response(channel) do
    %{
      response_type: "ephemeral",
      text: "Successfully subscribed #{channel} to alerts."
    }
  end

  def unsubscribe_response(channel) do
    %{
      response_type: "ephemeral",
      text: "Successfully unsubscribed #{channel} to alerts."
    }
  end

  def notifications_response() do
    %{
      response_type: "ephemeral",
      text: "Successfully subscribed to personal alerts."
    }
  end

  def monitor_not_found(_monitors = []) do
    ask_user_to_perform_monitor_selection()
  end

  def monitor_not_found(monitors) do
    %{
      response_type: "ephemeral",
      blocks: [
        %{
          type: "section",
          text: text_block("""
          Sorry, I don't recognize that command. \
          If you're looking for monitor details, here's a list of the ones you have access to.
          """, type: "mrkdwn"),
          accessory: %{
                      type: "static_select",
                      placeholder: text_block("Select a service", emoji: true),
                      options:
                        monitors
                        |> Enum.sort_by(fn m -> String.downcase(m.name) end, &<=/2) # sorts monitors by name in ascending order
                        |> Enum.take(@select_cutoff_count)
                        |> Enum.map(fn m ->
                                    %{
                                      text: text_block("#{m.name} (#{m.logical_name})", emoji: true),
                                      value: m.logical_name
                                    }
                                  end),
                      action_id: "choose-monitor"
          }
        }
      ]
    }
  end

  ### help ###

  def help() do
    commands = [
      {"/metrist", "Check the status of a service. You'll be prompted to choose one from a list."},
      {"/metrist list", "See high-level status of all Metrist-monitored services."},
      {"/metrist <monitor-name>", "Check the status of a specific service."},
      {"/metrist <monitor-name> details", "See detailed statistics about a specific service."},
      {"/metrist notifications", "Manage DM notifications."},
      {"/metrist subscriptions <channel-name>", "Manage channel subscriptions."},
      {"/metrist subscriptions list", "See all the subscriptions."},
      {"/metrist subscriptions list <channel-name>", "See all the subscriptions for a channel."},
      {"/metrist help", "You're reading it now! :smile:"}
    ]
  %{
    response_type: "ephemeral",
    blocks: [
      %{
        type: "section",
        text: text_block("Metrist responds to slash commands. Here they are.", type: "mrkdwn")
        },
        %{
          type: "context",
          elements: Enum.map(commands, fn {a, b} ->
          text_block("`#{a}` #{b}", type: "mrkdwn") end )
        }
      ]
    }
  end

  ### default + settings ###

  def default do
    %{
      response_type: "ephemeral",
      text: "Can't help you right now."
      }
  end

  def default(message) do
    %{
      response_type: "ephemeral",
      text: message
    }
  end




  def alert_message(snapshot, monitor) do
    header =
      make_alert_header(
        snapshot,
        monitor.name,
        monitor.logical_name
      )

    grouped_check_details = snapshot.check_details
    |> Enum.reject(& &1.state == :up)
    |> Enum.group_by(& &1.check_id)

    details = Enum.flat_map(grouped_check_details, fn {check_id, check_details} ->
      check_name = case List.first(check_details) do
        %{name: nil} -> check_id
        %{name: name} -> name
      end

      header = %{
        type: "section",
        text: text_block("*#{check_name}*", type: "mrkdwn")
      }

      checks = Enum.take(check_details, @check_instance_cutoff_count)
        |> Enum.map(fn detail ->
        last_check_time = Timex.Format.DateTime.Formatters.Relative.format!(detail.last_checked, "{relative}")

        text_block("#{check_emoji(detail.state)} [#{detail.instance}] #{detail.message} ⏱ *#{last_check_time}*", type: "mrkdwn")
      end)

      inner_details = %{
        type: "context",
        elements: checks
      }

      [header, inner_details, @divider_block]
    end)
    |> add_status_page_component_blocks(snapshot.status_page_component_check_details,
      monitor_name: monitor.logical_name,
      check_details_filter_fn: fn cd -> cd.state != :up end
    )
    |> maybe_add_cutoff_exceeded_message(
      snapshot,
      grouped_check_details,
      monitor,
      fn details -> details.state != :up end
    )

    footer =
      [
        make_action_button(monitor.logical_name, [show_expand_button: false])
      ]
      |> maybe_metrist_last_checked(snapshot)

    header ++ details ++ footer
  end

  def maybe_metrist_last_checked(existing_blocks, snapshot) do
    case Backend.RealTimeAnalytics.Snapshotting.has_default_last_checked?(snapshot) do
      true -> existing_blocks
      false ->
        last_checked_time = Timex.Format.DateTime.Formatters.Relative.format!(snapshot.last_checked, "{relative}")
        [
          %{
            type: "section",
            text: text_block("⏱ Metrist last checked #{last_checked_time}.")
          }
        |
        existing_blocks
        ]
    end
  end

  def add_status_page_component_blocks(check_details, status_page_check_details, opts \\ [])
  def add_status_page_component_blocks(check_details, [_|_] = status_page_check_details, opts) do
    filter_fn = Keyword.fetch!(opts, :check_details_filter_fn)
    monitor_name = Keyword.fetch!(opts, :monitor_name)

    header = %{
      type: "section",
      text: text_block("*#{monitor_name} status page components*", type: "mrkdwn")
    }

    checks =
      Enum.filter(status_page_check_details, & filter_fn.(&1))
      # Bubble most serious states to the top before cut off
      |> Enum.sort(fn left, right ->
          cond do
            left.state == right.state && left.name == right.name ->
              left.instance <= right.instance
            left.state == right.state ->
              left.name <= right.name
            true ->
              Snapshot.get_state_weight(left.state) >= Snapshot.get_state_weight(right.state)
          end
        end)
      |> Enum.take(@check_instance_cutoff_count)
      |> Enum.map(fn detail ->
        # If we have an instance (which we will for gcp/azure/aws) then show it
        instance_text = if is_nil(detail.instance) do
          ""
        else
          " - #{detail.instance}"
        end
        %{
          type: "context",
          elements: [
            text_block(
              "#{status_emoji(detail.state)} #{detail.message}#{instance_text} -> #{detail.state}",
              type: "mrkdwn"
            )
          ]
        }
      end)

    if Enum.empty?(checks) do
      check_details
    else
      check_details ++ [header | checks] ++ [@divider_block]
    end
  end
  def add_status_page_component_blocks(check_details, _status_page_check_details,  _opts), do: check_details

  def check_instance_cutoff_exceeded?(status_page_component_check_details, grouped_check_details, count, status_page_check_details_filter_fn) do
    Enum.any?(grouped_check_details, fn {_check_id, check_details} -> length(check_details) > count end)
      or Enum.count(status_page_component_check_details, & status_page_check_details_filter_fn.(&1)) > count
  end

  defp text_block(text, opts \\ []) do
    default_opts = [type: "plain_text"]

    %{ text: text }
    |> Map.to_list()
    |> Keyword.merge(default_opts)
    |> Keyword.merge(opts)
    |> Map.new()
  end

  def monitor_emoji(:up), do: "🎉"
  def monitor_emoji(:degraded), do: "⚠️"
  def monitor_emoji(:issues), do: "💥"
  def monitor_emoji(:down), do: "🛑"
  def monitor_emoji(_), do: ""

  def check_emoji(:up), do: "🎉"
  def check_emoji(:degraded), do: "🐢️"
  def check_emoji(:down), do: "🔥"
  def check_emoji(:blocked), do: "🧱"
  def check_emoji(_), do: ""

  def state_text(:up), do: "up and running"
  def state_text(:degraded), do: "in a degraded state"
  def state_text(:issues), do: "partially down"
  def state_text(:down), do: "down"
  def state_text(_), do: ""


  def status_emoji(:up), do: "🟢"
  def status_emoji(:degraded), do: "🟡"
  def status_emoji(:down), do: "⭕"
  def status_emoji(:blocked), do: "🚧"
  def status_emoji(_), do: ""
end
