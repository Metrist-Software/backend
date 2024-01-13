defmodule Mix.Tasks.Metrist.SetTwitterHashtags do
  use Mix.Task
  require Logger
  alias Mix.Tasks.Metrist.Helpers

  @opts [
    :env,
    :account_id,
    :monitor_logical_name,
    {:hashtag, nil, :keep, [],
    "A hashtag for the monitor's Twitter timeline"}
  ]
  @shortdoc "Set twitter hashtags for a monitor"
  @moduledoc """
  #{@shortdoc}.

  Note that this command will just set the list of hashtags to the ones that are specified on the
  command line here, it will not preserve current hashtags. Also note that for now, we will only
  use SHARED - specifying account_id is there for compatibility but currently not used.

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Helpers.start_repos(options.env)

    Helpers.send_command(
      %Domain.Monitor.Commands.SetTwitterHashtags{
        id: options.monitor_id,
        hashtags: options.hashtag
      },
      options.env)
  end
end
