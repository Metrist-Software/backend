defmodule Mix.Tasks.Metrist.OneOff.BackfillAccountOriginalUser do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc "Backfills original user id for accounts"

  @opts [
    :env,
    :dry_run,
  ]

  @moduledoc """
  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    options = Helpers.parse_args(@opts, args)
    Helpers.start_repos(options.env)

    Application.ensure_all_started(:commanded)
    Application.ensure_all_started(:commanded_eventstore_adapter)
    {:ok, _} = Backend.App.start_link()

    accounts = Backend.Projections.list_accounts()
    |> Enum.map(fn account -> {account.id, account} end)
    |> Map.new()

    # UserAdded not reliable for historial backfill, but should be safe to use to set original user going forward
    # Instead, we read and merge the User Created, Updated, and AccountIdUpdate events,
    # taking only the first one chronologically per account, to determine the
    # original user on an account

    created_events = get_stream("TypeStream.Elixir.Domain.User.Events.Created")
    |> Enum.reduce(%{}, fn curr, acc ->
      Map.put_new(acc, curr.data.user_account_id, {curr.created_at, curr.data.id})
    end)
    |> Map.delete(nil)

    updated_events = get_stream("TypeStream.Elixir.Domain.User.Events.Updated")
    |> Enum.reduce(%{}, fn curr, acc ->
      Map.put_new(acc, curr.data.user_account_id, {curr.created_at, curr.data.id})
    end)
    |> Map.delete(nil)

    account_id_updated_events = get_stream("TypeStream.Elixir.Domain.User.Events.AccountIdUpdate")
    |> Enum.reduce(%{}, fn curr, acc ->
      Map.put_new(acc, curr.data.user_account_id, {curr.created_at, curr.data.id})
    end)
    |> Map.delete(nil)

    merge_fn = fn _key, {dt_1, user_1}, {dt_2, user_2} ->
      case DateTime.compare(dt_1, dt_2) do
        :gt -> {dt_2, user_2}
        _ -> {dt_1, user_1}
      end
    end

    original_user_ids = created_events
    |> Map.merge(updated_events, merge_fn)
    |> Map.merge(account_id_updated_events, merge_fn)
    |> IO.inspect(limit: :infinity)


    original_user_ids
    |> Enum.reduce(Ecto.Multi.new(), fn {account_id, {_created_at, user_id}}, multi ->
      if Map.has_key?(accounts, account_id) do
        changeset = Ecto.Changeset.change(accounts[account_id], original_user_id: user_id)

        Ecto.Multi.update(multi, account_id, changeset)
      else
        multi
      end
    end)
    |> Backend.Repo.transaction()

    accounts
    |> Enum.reduce([], fn {id, val}, acc ->
      if Map.has_key?(original_user_ids, id) do
        acc
      else
        [val.id | acc]
      end
    end)
    |> IO.inspect(label: "The following accounts have had no associated users")
  end

  def get_stream(name) do
    case Commanded.EventStore.stream_forward(Backend.App, name) do
      {:error, _} -> []
      stream -> stream
    end
  end
end
