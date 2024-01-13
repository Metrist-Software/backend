defmodule BackendWeb.LandingPageSupportController do
  @moduledoc """
  This module contains publicly accessible API handlers that are mostly
  exposed as "obfuscated versioned" calls - a random string is inserted
  in the path that:

  * Makes the route hard to guess
  * Serves as a version tag in case we need to evolve calls
  * Ensures that if people discover and use it, breakage can be countered with
    "well, and you thought an API call with a long random string in it would
     be supported?" ;-)

  """

  use BackendWeb, :controller

  @doc """
  Returns a JSON structure that has the data for a Google, AWS or Azure
  state summary.
  """
  def cloud_state_overview(conn, params) do
    cloud = Map.get(params, "cloud")
    account_id = Domain.Helpers.shared_account_id()

    mons =
      account_id
      |> Backend.Projections.list_monitors([:monitor_tags])
      |> Enum.map(fn m ->
        %{logical_name: m.logical_name, tags: Backend.Projections.Dbpa.Monitor.get_tags(m)}
      end)
      |> Enum.filter(&Enum.any?(&1.tags, fn t -> t == cloud end))
      |> Enum.map(fn m -> m.logical_name end)
      |> Enum.map(&Backend.RealTimeAnalytics.get_snapshot_or_nil(account_id, &1))
      |> Enum.reject(&is_nil/1)

    json(conn, snapshots_to_cloud_state_overview(mons))
  end

  def snapshots_to_cloud_state_overview(snaps) do
    mons =
      snaps
      |> Enum.map(fn s ->
        %{
          monitor_logical_name: s.monitor_id,
          last_checked: s.last_checked,
          state: s.state,
          check_details:
            Enum.map(s.check_details, fn d ->
              %{
                check_id: d.check_id,
                instance: d.instance,
                name: d.name,
                state: d.state
              }
            end)
        }
      end)

    order = [:up, :degraded, :issues, :down]

    overall_state =
      mons
      |> Enum.reduce(0, fn m, s ->
        ms = Enum.find_index(order, &(&1 == m.state))
        max(s, ms)
      end)

    overall_state = Enum.at(order, overall_state)

    last_checked =
      Enum.reduce(mons, ~N"1970-01-01 00:00:00.000", fn m, t ->
        case NaiveDateTime.compare(m.last_checked, t) do
          :lt -> t
          :eq -> t
          :gt -> m.last_checked
        end
      end)

    %{
      monitors: mons,
      state: overall_state,
      last_checked: last_checked
    }
  end
end
