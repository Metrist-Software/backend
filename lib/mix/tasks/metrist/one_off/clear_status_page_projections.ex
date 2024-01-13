defmodule Mix.Tasks.Metrist.OneOff.ClearStatusPageProjections do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @opts [
    :dry_run,
    :env
  ]

  @moduledoc """
  Clears all status_page_components and status_page_subscriptions from all accounts
  Then issues status page resets for every status page
  """

  def run(args) do
    Logger.configure(level: :info)

    opts = Helpers.parse_args(@opts, args)

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)

    Application.ensure_all_started(:postgrex)

    Mix.Shell.IO.yes?("Are you sure you want to clear status page projection data? This will clear all status_page_components and status_page_subscriptions from all accounts?", default: :no)
    |> do_clear(opts)
  end

  defp do_clear(true, options) do
    Logger.info("Running status page clear")
    {:ok, conn} = Postgrex.start_link(Application.get_env(:backend, Backend.Repo))

    for account <- Backend.Projections.list_accounts() do
      case options.dry_run do
        true ->
          Logger.info("DRY RUN - TRUNCATE TABLE \"dbpa_#{account.id}\".status_page_subscriptions", [])
          Logger.info("DRY RUN - TRUNCATE TABLE \"dbpa_#{account.id}\".status_page_components", [])
        false ->
          Postgrex.query!(conn, "TRUNCATE TABLE \"dbpa_#{account.id}\".status_page_subscriptions", [])
          Postgrex.query!(conn, "TRUNCATE TABLE \"dbpa_#{account.id}\".status_page_components", [])
      end
    end

    for sp <- Backend.Projections.Dbpa.StatusPage.status_pages do
      %Domain.StatusPage.Commands.Reset{
        id: sp.id
      }
    end
    |> Mix.Tasks.Metrist.Helpers.send_commands(options.env, options.dry_run)

    Logger.info("Done")
  end

  defp do_clear(false, _options), do: Logger.info("Stopping status page clear")
end
