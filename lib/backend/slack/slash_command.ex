defmodule Backend.Slack.SlashCommand do

  use TypedStruct

  typedstruct enforce: true do
    field :token, String.t()
    field :team_id, String.t()
    field :team_domain, String.t()
    field :enterprise_id, String.t()
    field :enterprise_name, String.t()
    field :channel_id, String.t()
    field :channel_name, String.t()
    field :user_id, String.t()
    field :username, String.t()
    field :command, String.t()
    field :text, String.t()
    field :response_url, String.t()
    field :trigger_id, String.t()
    field :account_id, String.t()
  end

end
