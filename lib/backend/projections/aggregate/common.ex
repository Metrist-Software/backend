defmodule Backend.Projections.Aggregate.Common do
  @moduledoc """
  Some commonly-used code to support our metrics collection ("aggregate")
  code.
  """

  @doc """
  Return the NaiveDateTime that represents the cut-off time for the indicated
  period.
  """
  def since(amount, period), do: Timex.shift(NaiveDateTime.utc_now(), [{period, -amount}])

  import Ecto.Query

  @doc """
  Cleanup old records.
  """
  def cleanup(module_name) do
    cleanup_date = since(1, :months)
    # we only need up to 1 month back, rest is in the event store if we need it
    module_name
    |> where([a], a.time <= ^cleanup_date)
    |> Backend.Repo.delete_all()
  end
end
