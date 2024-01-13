defmodule Backend.Notifications.EmailHandler do
  @event_type Domain.NotificationChannel.Events.attempt_type("email")

  @email_html_body """
<div>{{message}}</div>
<br />
<br />
<a href="https://app.metrist.io/monitors/alerting">Manage Subscriptions</a>
"""

  @email_text_body """
{{message}}

Manage Subscriptions at https://app.metrist.io/monitors/alerting
"""

  use Backend.Notifications.Handler,
    event_type: @event_type

  @impl true
  def get_response(req) do
    Backend.Application.do_aws_request(req)
  end

  @impl true
  def make_request(_event, %Backend.Projections.Dbpa.Alert{is_instance_specific: true}), do: :skip
  def make_request(event, alert) do
    dst = %{
      to: [event.channel_identity],
      cc: [],
      bcc: []
    }

    message = Map.get(alert.formatted_messages, "email", "")

    html_message = message
    |> String.replace("\n", "<br />")
    |> String.replace("\t", "&emsp;")

    msg = %{
      subject: %{
        data: "Metrist Alert - #{alert.monitor_name}",
        charset: "UTF-8"
      },
      body: %{
        html: %{
          data: String.replace(@email_html_body, "{{message}}", html_message),
          charset: "UTF-8"
        },
        text: %{
          data: String.replace(@email_text_body, "{{message}}", message),
          charset: "UTF-8"
        }
      }
    }

    src = "\"Metrist Software\" <alerts@metrist.io>"

    ExAws.SES.send_email(dst, msg, src)
  end
end
