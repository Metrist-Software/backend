defmodule Backend.RealTimeAnalytics.TeamsBody do
  def alert_message(snapshot, monitor) do
    # Show a issues message if one status page component is not healthy
    header_state = Backend.RealTimeAnalytics.Snapshotting.notification_header_state(snapshot)

    header = [
      %{
        type: "RichTextBlock",
        inlines: [
          %{
            type: "TextRun",
            size: "Medium",
            text: monitor_emoji(header_state)
          },
          %{
            type: "TextRun",
            size: "Medium",
            weight: "Bolder",
            text: "#{monitor.name} is #{state_text(header_state)}."
          }
        ]
      },
      %{
        type: "TextBlock",
        size: "Small",
        text: "@metrist #{monitor.logical_name}"
      }
    ]

    details = snapshot.check_details
    |> Enum.reject(& &1.state == :up)
    |> Enum.group_by(& &1.check_id)
    |> Enum.flat_map(fn {check_id, check_details} ->
      check_name = case List.first(check_details) do
        %{name: name} -> name
        _ -> check_id
      end

      header = %{
        type: "TextBlock",
        text: "*#{check_name}*",
        weight: "Bolder",
        separator: true,
        wrap: true
      }

      details = Enum.map(check_details, fn detail ->
        last_check_time = Timex.Format.DateTime.Formatters.Relative.format!(detail.last_checked, "{relative}")

        %{
          type: "TextBlock",
          text: "#{check_emoji(detail.state)} [#{detail.instance}] #{detail.message} ⏱ *#{last_check_time}*",
          wrap: true
        }
      end)

      [header | details]
    end)

    details = if snapshot.status_page_component_check_details != [] do
      header = %{
        type: "TextBlock",
        text: "#{monitor.name} status page component",
        weight: "Bolder",
        separator: true,
        wrap: true
      }

      components = snapshot.status_page_component_check_details
        |> Enum.reject(& &1.state == :up)
        |> Enum.map(fn detail ->
          last_check_time = Timex.format!(detail.last_checked, "{relative}", :relative)
          %{
            type: "TextBlock",
            text: "#{check_emoji(detail.state)} [#{detail.instance}] #{detail.message} ⏱ *#{last_check_time}*",
            wrap: true
          }
        end)
      sp_blocks = [header | components]
      details ++ sp_blocks
    else
      details
    end

    last_checked_time = Timex.Format.DateTime.Formatters.Relative.format!(snapshot.last_checked, "{relative}")

    footer = [
      %{
        type: "TextBlock",
        text: "⏱ Metrist last checked #{last_checked_time}.",
        separator: true,
        wrap: true
      }
    ]

    %{
      "$schema" => "http://adaptivecards.io/schemas/adaptive-card.json",
      version: "1.3",
      type: "AdaptiveCard",
      body: header ++ details ++ footer,
      actions: [
        %{
          type: "Action.Submit",
          title: "Show Details",
          style: "positive",
          data: %{
            "metristCommand" => "#{monitor.logical_name} details"
          }
        }
      ]
    }
  end

  def monitor_emoji(:up), do: "🎉"
  def monitor_emoji(:degraded), do: "⚠️"
  def monitor_emoji(:issues), do: "💥"
  def monitor_emoji(:down), do: "🛑"
  def monitor_emoji(_), do: ""

  def check_emoji(:up), do: "🎉"
  def check_emoji(:degraded), do: "🐢️"
  def check_emoji(:down), do: "🔥"
  def check_emoji(_), do: ""

  def state_text(:up), do: "up and running"
  def state_text(:degraded), do: "in a degraded state"
  def state_text(:issues), do: "experiencing some issues"
  def state_text(:down), do: "down"
  def state_text(_), do: ""
end
