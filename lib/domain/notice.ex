defmodule Domain.Notice do
  use TypedStruct
  require Logger

  @derive Jason.Encoder
  defstruct [:id]

  alias __MODULE__.Commands
  alias __MODULE__.Events

  # Command handling

  def execute(%__MODULE__{id: nil}, c = %Commands.Create{}) do
    %Events.Created{
      id: c.id,
      monitor_id: c.monitor_id,
      summary: c.summary,
      description: c.description,
      end_date: c.end_date
    }
  end
  def execute(_user, %Commands.Create{}) do
    # Ignore duplicate registrations
    nil
  end
  def execute(%__MODULE__{id: nil}, c) do
    Logger.error("Invalid command on notice that has not seen a Create: #{inspect c}")
    {:error, :no_create_command_seen}
  end

  def execute(_notice, c = %Commands.Update{}) do
    [
      %Events.ContentUpdated{id: c.id, summary: c.summary, description: c.description},
      %Events.EndDateUpdated{id: c.id, end_date: c.end_date}
    ]
  end

  def execute(_notice, c = %Commands.Clear{}) do
    %Events.EndDateUpdated{id: c.id, end_date: NaiveDateTime.utc_now()}
  end

  def execute(_notice, c = %Commands.MarkRead{}) do
    %Events.MarkedRead{id: c.id, user_id: c.user_id}
  end

  # Event Processing

  def apply(_notice, e = %Events.Created{}) do
    %__MODULE__{id: e.id}
  end

  def apply(notice, %Events.ContentUpdated{}) do
    notice
  end

  def apply(notice, %Events.EndDateUpdated{}) do
    notice
  end

  def apply(notice, %Events.MarkedRead{}) do
    notice
  end
end
