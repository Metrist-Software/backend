defmodule Backend.TelemetryRepo do
  use Ecto.Repo,
    otp_app: :backend,
    adapter: Ecto.Adapters.Postgres
end


defmodule Backend.TelemetrySourceRepo do
  @moduledoc """
  Separate stub connection for Telemetry.ToLocal server so that we can connect to source to copy telem
  """
  use Ecto.Repo,
    otp_app: :backend,
    adapter: Ecto.Adapters.Postgres
end


defmodule Backend.TelemetryWriteRepo do
  @moduledoc """
  The write connection for telemetry
  """

  use Ecto.Repo,
    otp_app: :backend,
    adapter: Ecto.Adapters.Postgres

  require Logger

  def create_table_if_required() do
    File.read!("./sql/timescale-create-hypertable.sql")
    |> String.split(";")
    |> Enum.each(&Ecto.Adapters.SQL.query!(Backend.TelemetryWriteRepo, &1))
  end
end
