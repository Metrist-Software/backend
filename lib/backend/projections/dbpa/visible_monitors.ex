defmodule Backend.Projections.Dbpa.VisibleMonitor do
  use Ecto.Schema

  @primary_key false
  schema "visible_monitors" do
    field :monitor_logical_name, :string
  end

  def visible_monitor_logical_names(acct) do
    __MODULE__
    |> Backend.Repo.all(prefix: Backend.Repo.schema_name(acct))
    |> Enum.map(& &1.monitor_logical_name)
  end

  def default_visible_monitor_logical_names() do
    []
  end
end
