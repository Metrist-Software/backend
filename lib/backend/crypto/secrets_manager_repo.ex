defmodule Backend.Crypto.SecretsManagerRepo do
  @moduledoc """
  SecretsManagerBackend maintains keys in AWS Secrets Manager. We also keep a very short lived cache, because writes are
  sometimes eventually consistent so a second read may not always get a key that just got created. This should help, but
  not prevent this situation.
  """

  @behaviour Domain.CryptRepo

  require Logger
  import Cachex.Spec

  defmodule KeyMeta do
    defstruct [
      :id,
      :is_default,
      :owner_id,
      :owner_type,
      :scheme,
      :key
    ]

    def from_map(tags) do
      map =
        for %{"Key" => "key:" <> key, "Value" => value} <- tags, into: %{} do
          {key, value}
        end

      %__MODULE__{
        id: map["id"],
        is_default: String.to_existing_atom(map["is_default"]),
        owner_id: map["owner_id"],
        owner_type: map["owner_type"],
        scheme: map["scheme"]
      }
    end

    def to_tags(meta) do
      map =
        Map.from_struct(meta)
        |> Map.update!(:is_default, &Atom.to_string/1)

      for {key, value} <- map, key != :key do
        %{"Key" => "key:#{key}", "Value" => value}
      end
    end

    def to_key_data(meta) do
      {meta.id, meta.scheme, meta.key}
    end
  end

  @impl true
  def initialize() do
    # Note that this will end up linking the cache to the application pid. Given that we
    # rely on this extensively and Cachex is unlikely to crash to begin with, this should
    # not be an issue.
    {:ok, pid} =
      Cachex.start_link(__MODULE__,
        expiration:
          expiration(
            default: :timer.seconds(60),
            interval: :timer.seconds(60),
            lazy: false
          )
      )

    Logger.info("Cache for AWS Secrets Manager key management started with pid #{inspect pid}")

    :ok
  end

  @impl true
  def get(id) do
    case Cachex.get(__MODULE__, id) do
      {:ok, nil} ->
        secret_id = key_path(id)

        meta =
          with {:ok, key} <- get_secret(secret_id),
               {:ok, partial_key_meta} <- secret_tags(secret_id) do
            %KeyMeta{partial_key_meta | key: key}
          end

        meta
        |> cached()

      {:ok, value} ->
        value
    end
    |> KeyMeta.to_key_data()
  end

  @impl true
  def key_for(owner_type, id) do
    case Cachex.get(__MODULE__, {owner_type, id}) do
      {:ok, nil} ->
        meta =
          case find_secret(owner_type, id) do
            {:ok, arn, %KeyMeta{} = partial_key_meta} ->
              with {:ok, key} <- get_secret(arn) do
                %KeyMeta{partial_key_meta | key: key}
              end

            {:error, :not_found} ->
              Logger.info(
                "SecretsManagerBackend key_for. Key not found for owner_type: #{owner_type}, id: #{id}. Creating a new one"
              )

              with {:ok, %KeyMeta{} = key_meta} <- create_secret(owner_type, id) do
                Logger.info(
                  "SecretsManagerBackend key_for. Created new key for owner_type: #{owner_type}, id: #{id}"
                )

                key_meta
              end

            other ->
              other
          end

        meta
        |> cached()

      {:ok, value} ->
        value
    end
    |> KeyMeta.to_key_data()
  end

  # public for testing
  @doc false
  @spec find_secret(String.t(), String.t()) :: {:ok, String.t(), %KeyMeta{}} | {:error, atom()}
  def find_secret(owner_type, owner_id, helper_mod \\ __MODULE__) do
    filters =
      [{"key:owner_type", owner_type}, {"key:owner_id", owner_id}]
      |> Enum.flat_map(fn {key, value} ->
        [%{"Key" => "tag-key", "Values" => [key]}, %{"Key" => "tag-value", "Values" => [value]}]
      end)

    # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_ListSecrets.html
    with {:ok, response} <- helper_mod.aws_list_secrets(filters: filters) do
      case response do
        # ListSecrets does a prefix match on the tags so we need to filter the results to find the exact match
        # We also need to pull out the default key(s), non-default keys are read-only keys that for
        # some reason we generated a newer version for (note that we could just use the AWS SM facilities
        # for key versioning here instead).
        %{"SecretList" => [_ | _] = list} ->
          filtered_result =
            for item <- list,
                meta = KeyMeta.from_map(item["Tags"]),
                meta.is_default and meta.owner_type == owner_type and meta.owner_id == owner_id,
                do: {item["ARN"], meta}

          case filtered_result do
            # We can have more than one result, that's fine, it's how things work.
            [{arn, meta} | _rest] -> {:ok, arn, meta}
            [] -> {:error, :not_found}
          end

        %{"SecretList" => []} ->
          {:error, :not_found}

        rest ->
          rest
      end
    end
  end

  # public for testing
  @doc false
  def create_secret(owner_type, owner_id) do
    scheme = Domain.CryptUtils.current_scheme()

    key_meta = %KeyMeta{
      id: Domain.Id.new(),
      is_default: true,
      owner_id: owner_id,
      owner_type: owner_type,
      scheme: Atom.to_string(scheme),
      key: Domain.CryptUtils.gen_random(Domain.CryptUtils.key_bytes(scheme))
    }

    tags = [
      # Add env to tag to help us retrieve this secret by env
      %{
        "Key" => "env",
        "Value" => Application.get_env(:backend, :encryption_key_env_tag, "dev1")
      }
      | KeyMeta.to_tags(key_meta)
    ]

    secret = [
      client_request_token: Ecto.UUID.generate(),
      tags: tags,
      name: key_path(key_meta.id),
      secret_string: key_meta.key
    ]

    with {:ok, _response} <- aws_create_secret(secret) do
      {:ok, key_meta}
    end
  end

  # secret_id is the ARN or name of the secret
  defp get_secret(secret_id) do
    with {:error, reason} <- aws_get_secret_value(secret_id) do
      Logger.error(
        "SecretsManagerBackend get_secret. Failed to get secret, with reason: #{inspect(reason)}"
      )

      :error
    else
      {:ok, %{"SecretString" => secret}} ->
        {:ok, secret}

      {:ok, _} ->
        Logger.error(
          "SecretsManagerBackend get_secret. SecretString not found for secret_id:#{secret_id}"
        )

        :error

      other ->
        other
    end
  end

  defp secret_tags(secret_id) do
    with {:ok, %{"Tags" => tags}} <- aws_describe_secret(secret_id) do
      {:ok, KeyMeta.from_map(tags)}
    end
  end

  defp key_path(id) do
    prefix = Application.get_env(:backend, :encryption_key_secret_prefix, "/dev1/encryption-keys")

    "#{prefix}/#{id}"
  end

  # Caching helpers. Public for easy mocking.

  @doc false
  def cached(key_meta) do
    # An item so nice, we have to cache it twice... This way retrieval is quick.
    Cachex.put(__MODULE__, {key_meta.owner_type, key_meta.owner_id}, key_meta)
    Cachex.put(__MODULE__, key_meta.id, key_meta)
    key_meta
  end

  # AWS helpers. Public for easy mocking.

  @doc false
  def aws_get_secret_value(secret_id) do
    secret_id
    |> ExAws.SecretsManager.get_secret_value()
    |> Backend.Application.do_aws_request()
  end

  @doc false
  def aws_describe_secret(secret_id) do
    secret_id
    |> ExAws.SecretsManager.describe_secret()
    |> Backend.Application.do_aws_request()
  end

  @doc false
  def aws_create_secret(secret) do
    secret
    |> ExAws.SecretsManager.create_secret()
    |> Backend.Application.do_aws_request()
  end

  @doc false
  def aws_list_secrets(filters) do
    filters
    |> ExAws.SecretsManager.list_secrets()
    |> Backend.Application.do_aws_request()
  end
end
