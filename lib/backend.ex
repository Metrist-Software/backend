defmodule Backend do
  @moduledoc """
  Backend keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Looks up `Application` config
  ## Examples
      config :backend, :files, [
        uploads_dir: Path.expand("../priv/uploads", __DIR__),
        host: [scheme: "http", host: "localhost", port: 4000],
      ]
      iex> Backend.config([:files, :uploads_dir])
      iex> Bbackend.config([:files, :host, :port])
  """
  def config([main_key | rest] = keyspace, default \\ nil) when is_list(keyspace) do
    main = Application.fetch_env!(:backend, main_key)
    Enum.reduce_while(rest, main, fn next_key, current ->
      case Keyword.fetch(current, next_key) do
        {:ok, val} -> {:cont, val}
        :error -> {:halt, default}
      end
    end)
  end

end
