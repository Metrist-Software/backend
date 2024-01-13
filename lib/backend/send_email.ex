defmodule Backend.SendEmail do
  require Logger

  @invite_text_body """
Hello,

{{organization}} has invited you to use Metrist along with them! Metrist monitors the health and availability of the APIs and SaaS products that {{organization}} uses to serve customers and work efficiently. With Metrist, you will be able to see real-time metrics and historical trends of the services you rely on most, so you can resolve incidents more quickly and better manage vendor SLAs.

Click this one-time use link to accept the invitation and get started: {{link}}

Metrist Software, Inc.
https://metrist.io/
"""

  @invite_html_body """
<p>Hello,</p>

<p>{{organization}} has invited you to use Metrist along with them! Metrist monitors the health and availability of the APIs and SaaS products that {{organization}} uses to serve customers and work efficiently. With Metrist, you will be able to see real-time metrics and historical trends of the services you rely on most, so you can resolve incidents more quickly and better manage vendor SLAs.</p>

<p>Click this one-time use link to accept the invitation and get started: <a href="{{link}}">{{link}}</a></p>

<p>Metrist Software, Inc.</p>
<p><a href="https://metrist.io/">https://metrist.io/</a></p>
"""

  def send_invite_email(to_email, account_name, invite_link) when is_binary(to_email) and is_binary(account_name) and is_binary(invite_link) do
    case System.get_env("DEFAULT_FROM_EMAIL") do
      nil ->
        Logger.warning("Env DEFAULT_FROM_EMAIL not set - Not sending email")
        {:error, :no_default_email}
      from_email -> do_send_invite_email(to_email, from_email, account_name, invite_link)
    end
  end
  def send_invite_email(_to_email, _account_name, _invite_link) do
    {:error, :invalid_params}
  end

  defp do_send_invite_email(to_email, from_email, account_name, invite_link) do
    dst = %{
      to: [to_email],
      cc: [],
      bcc: []
    }

    msg = %{
      subject: %{
        data: "You've been invited to Metrist!",
        charset: "UTF-8"
      },
      body: %{
        html: %{
          data:
            @invite_html_body
            |> String.replace("{{organization}}", account_name)
            |> String.replace("{{link}}", invite_link),
          charset: "UTF-8"
        },
        text: %{
          data:
            @invite_text_body
            |> String.replace("{{organization}}", account_name)
            |> String.replace("{{link}}", invite_link),
          charset: "UTF-8"
        }
      }
    }

    src = "\"Metrist Software\" <#{from_email}>"

    ExAws.SES.send_email(dst, msg, src)
    |> Backend.Application.do_aws_request()
  end
end
