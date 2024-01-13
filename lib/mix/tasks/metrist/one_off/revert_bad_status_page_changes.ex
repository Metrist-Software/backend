defmodule Mix.Tasks.Metrist.OneOff.RevertBadStatusPageChanges do
  use Mix.Task
  alias Mix.Tasks.Metrist.Helpers
  require Logger

  @shortdoc ""

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

    Logger.configure(level: :info)

    Application.ensure_all_started(:commanded)
    Application.ensure_all_started(:commanded_eventstore_adapter)
    {:ok, _} = Backend.App.start_link()

    Backend.Projections.list_monitors(Domain.Helpers.shared_account_id())
    |> Enum.map(& &1.logical_name)
    |> Enum.each(& try_do(fn -> process_monitor(&1, options) end))
  end

  def process_monitor(monitor_logical_name, options) do
    Logger.info("Starting to process #{monitor_logical_name}")

    status_page_id = case Backend.Projections.status_page_by_name(monitor_logical_name) do
      %{id: id} -> id
      _ -> nil
    end

    changes_to_remove = get_stream(status_page_id)
    |> Enum.reduce(%{agg: %Domain.StatusPage{}, bad_change_ids: []}, fn curr, acc ->
      updated_agg = Domain.StatusPage.apply(acc.agg, curr.data)

      case curr.data do
        event=%Domain.StatusPage.Events.ComponentStatusChanged{} ->
          component_id = {event.component, event.instance}
          if is_same(acc.agg, updated_agg, component_id) do
            %{
              agg: updated_agg,
              bad_change_ids: [event.change_id | acc.bad_change_ids]
            }
          else
            %{
              agg: updated_agg,
              bad_change_ids: acc.bad_change_ids
            }
          end
        event=%Domain.StatusPage.Events.ComponentChangeRemoved{} ->
          %{
            agg: updated_agg,
            bad_change_ids: List.delete(acc.bad_change_ids, event.change_id)
          }
        _ ->
          %{
            agg: updated_agg,
            bad_change_ids: acc.bad_change_ids
          }
      end
    end)
    |> Map.get(:bad_change_ids)

    if !Enum.empty?(changes_to_remove) do
      Enum.chunk_every(changes_to_remove, 100)
      |> Enum.map(fn change_ids ->
        %Domain.StatusPage.Commands.RemoveComponentChanges{
          id: status_page_id,
          change_ids: change_ids
        }
      end)
      |> Enum.each(fn cmd ->
        Helpers.send_command(cmd, options.env, options.dry_run)
      end)

      Logger.info("Issued commands to remove #{length(changes_to_remove)} status page changes for #{monitor_logical_name}")
    else
      Logger.info("No status page changes to remove")
    end
  end

  def is_same(old_agg, new_agg, component_id) do
    [old_status, _] = Map.get(old_agg.components, component_id, [nil, nil])
    [new_status, _] = Map.get(new_agg.components, component_id, [nil, nil])

    old_status == new_status
  end

  def get_stream(name) do
    case Commanded.EventStore.stream_forward(Backend.App, name) do
      {:error, _} -> []
      stream -> stream
    end
  end

  # error handling wrapper written due to dev1 env having event structs that did not exist
  # e.g., 1st argument: not an already existing atom; :erlang.binary_to_existing_atom("Elixir.Domain.StatusPage.Events.ComponentAdded", :utf8)
  # shouldn't hypothetically happen in prod but going to leave it in for the moment...
  defp try_do(fun) do
    try do
      fun.()
    rescue
      err -> Logger.error(Exception.format(:error, err, __STACKTRACE__))
    end
  end
end
