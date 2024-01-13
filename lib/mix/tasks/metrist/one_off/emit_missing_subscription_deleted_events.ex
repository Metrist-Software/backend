defmodule Mix.Tasks.Metrist.OneOff.EmitMissingSubscriptionDeletedEvents do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @shortdoc "MET-865 Try our best to run the missing DeleteSubscriptions Commands and emit the corresponding SubscriptionDeleted events and clean up the account aggregates"

  # Technically it is possible, but not very likely, for this to delete a subscription that has not yet projected.
  # If it had applied to the aggregate but not made it to the DB yet this would issue a delete for it.
  # A risk we have to take to get everything back in sync. EventStore would have everything needed to issue a new SubscriptionAdded
  # if required.

  @opts [
    :dry_run,
    :env
  ]

  def run(args) do
    Logger.configure(level: :info)
    options = Helpers.parse_args(@opts, args)
    Mix.Tasks.Metrist.Helpers.start_repos(options.env)

    Application.ensure_all_started(:commanded)
    Application.ensure_all_started(:commanded_eventstore_adapter)
    {:ok, _} = Backend.App.start_link()

    Backend.Projections.list_accounts()
    |> Enum.map(fn account ->
      try do
        account_state = Commanded.Aggregates.Aggregate.aggregate_state(Backend.App, Domain.Account, account.id)

        dbpa_subscription_ids = Backend.Projections.get_subscriptions_for_account(account.id)
        |> Enum.map(&(&1.id))

        Logger.info("Number of subscriptions on aggregate for #{account.id}: #{length(account_state.subscriptions)}")
        Logger.info("Number of subscriptions in projections for #{account.id}: #{length(dbpa_subscription_ids)}")

        # diff what the aggregate thinks we have vs what's in the projections
        # The projections subscriptions could have been cascade deleted without updating the aggregate
        # We're taking the projections as source of truth here, just this one time, because of the cascades
        subscriptions_ids_to_delete = Enum.map(account_state.subscriptions, &(&1.id)) -- dbpa_subscription_ids

        case length(subscriptions_ids_to_delete) do
          0 -> nil
          _ ->
            %Domain.Account.Commands.DeleteSubscriptions{
              id: account.id,
              subscription_ids: subscriptions_ids_to_delete
            }
        end
      catch
        :exit, error ->
          Logger.error("Error checking Account #{account.id}: #{inspect(error)}")
      end
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil(&1))
    |> Helpers.send_commands(options.env, options.dry_run)
  end
end
