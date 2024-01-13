defmodule Backend.Twitter do
  @moduledoc """
  API for working with the Twitter counter subsystem
  """

  @doc """
  Return the counts as an array of `{timestamp, value}` tuples for
  the indicated monitor/hashtag.
  """
  require Logger

  def counts(monitor_logical_name, hashtag) do
    worker_name = Backend.Twitter.Supervisor.worker_name(monitor_logical_name, hashtag)
    if Swarm.whereis_name(worker_name) == :undefined do
      Logger.warn("Backend.Twitter.counts/2 cannot find worker for #{inspect {monitor_logical_name, hashtag}}")
      []
    else
      Backend.Twitter.Supervisor.worker_name(monitor_logical_name, hashtag, :via_tuple)
      |> Backend.Twitter.Worker.counts()
    end
  end
end
