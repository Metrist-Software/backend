defmodule Mix.Tasks.Metrist.OneOff.FixOldSubscriptionWorkspaces do
  use Mix.Task
  require Logger

  @shortdoc "Recreate old subscriptions that still reference their workspace with preceding identifier"

  def run(args) do
    {opts, []} =
      OptionParser.parse!(
        args,
        strict: [env: :string],
        aliases: [e: :env]
      )

    missing =
      [:env]
      |> Enum.filter(fn opt -> is_nil(opts[opt]) end)
    if length(missing) > 0, do: raise("Missing required option(s): #{inspect(missing)}")
    IO.inspect(opts, label: "Parsed options")

    #Mix.Tasks.Metrist.Helpers.assert_env!(opts[:env])

    config = opts[:env]
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")

    Mix.Tasks.Metrist.Helpers.config_to_env(config)

    Mix.Task.run("app.config")
    #Mix.Tasks.Metrist.Helpers.start_commanded()
    # Mix.Tasks.Metrist.Helpers.start_repos()

    # Get all subscriptions for all accounts, find any that point to a slack
    # workspace prepended with "SlackWorkspaces/" and replace them with the
    # correct ID
    # Only Slack subscriptions have this issue. Teams apparently didn't have any
    # from then and none of the other methods reference anything by ID

    accounts = Backend.Projections.list_accounts(type: :external)

    bad_subscriptions_by_account = accounts
    |> Enum.map(fn account ->
      subscriptions = Backend.Projections.get_subscriptions_for_account(account.id)
      |> Enum.filter(fn subscription ->
        case subscription.extra_config do
          %{"WorkspaceId" => <<"SlackWorkspaces/", _::binary>>} ->
            true
          _ ->
            false
        end
      end)

      {account.id, subscriptions}
    end)
    |> Enum.filter(fn
      {_id, []} -> false
      _ -> true
    end)

    cmds = Enum.flat_map(bad_subscriptions_by_account, fn {account_id, subscriptions} ->
      delete_command = %Domain.Account.Commands.DeleteSubscriptions{
        id: account_id,
        subscription_ids: Enum.map(subscriptions, & &1.id)
      }

      new_subscriptions = Enum.map(subscriptions, fn subscription ->
        %{"WorkspaceId" => <<"SlackWorkspaces/", workspace_id::binary>>} = subscription.extra_config

        %{
          subscription_id: Domain.Id.new(),
          monitor_id: subscription.monitor_id,
          delivery_method: subscription.delivery_method,
          identity: subscription.identity,
          regions: subscription.regions,
          display_name: subscription.display_name,
          extra_config: %{"WorkspaceId" => workspace_id} #
        }
      end)

      add_command = %Domain.Account.Commands.AddSubscriptions{
        id: account_id,
        subscriptions: new_subscriptions
      }

      [add_command, delete_command]
    end)

    Mix.Tasks.Metrist.Helpers.send_commands(cmds, opts[:env])
  end
end
