defmodule Domain.CryptRepo do
  @moduledoc """
  Abstraction and helpers for repositories for key information. The actual implementations
  live in Backend.
  """

  @doc """
  The currently configured repository. Only one can be active application-wide.
  """
  def current do
    Application.get_env(:backend, :crypt_repo, Backend.Crypto.EctoRepo)
  end

  @typedoc """
  Key type, a tuple of "{id, scheme, key}" data.
  """
  @type key_data :: {String.t(), String.t(), String.t()}

  @doc """
  Initialize the repository. Called early in application startup for the currently configured repository.
  """
  @callback initialize() :: :ok

  @doc """
  Fetch or generate the key for the specified owner. Used for encryption operations; if multiple keys
  are active, a random one can be returned. If the repository has no key, one is generated on the fly for
  the current scheme.
  """
  @callback key_for(owner_type :: String.t() | atom, id :: String.t()) :: key_data()

  @doc """
  Retrieve the key by its id.
  """
  @callback get(id :: String.t()) :: key_data()
end
