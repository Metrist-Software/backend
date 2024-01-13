defmodule Mix.Tasks.Metrist.OneOff.MigrateEncryptionKeysToSecretsManager do
  use Mix.Task
  alias Backend.Repo
  alias Mix.Tasks.Metrist.Helpers

  # ExAws.SecretsManager.create_secret typespec is outdated so we have to ignore dialyzer warnings
  @dialyzer {:nowarn_function, [run: 1, create_secret_request: 2]}

  @opts [
    :dry_run,
    :env
  ]

  @shortdoc "Copies the encryption keys from the DB to Secrets manager"

  @moduledoc """
    MIX_ENV=prod mix metrist.one_off.migrate_encryption_keys_to_secrets_manager --env dev1

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    opts.env
    |> Mix.Tasks.Metrist.Helpers.config_from_env()
    |> IO.inspect(label: "Config")
    |> Mix.Tasks.Metrist.Helpers.config_to_env()

    Mix.Tasks.Metrist.Helpers.start_repos(opts.env)
    Application.ensure_all_started(:postgrex)

    region =
      case opts.env do
        "dev1" -> "us-east-1"
        "prod" -> "us-west-2"
        _other -> raise "Invalid env"
      end

    list_keys()
    |> Enum.map(&create_secret_request(&1, opts))
    |> Enum.each(fn request ->
      ExAws.request(request, region: region)
      |> IO.inspect()
    end)
  end

  def list_keys() do
    Repo.all(Backend.Crypto.Key)
  end

  def create_secret_request(%Backend.Crypto.Key{} = key, opts) do
    # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_CreateSecret.html
    tags =
      [
        {"key:id", key.id},
        {"key:is_default", Atom.to_string(key.is_default)},
        {"key:key_id", key.key_id || ""},
        {"key:owner_id", key.owner_id},
        {"key:owner_type", key.owner_type},
        {"key:scheme", key.scheme},
        {"env", opts.env}
      ]
      |> Enum.map(fn {key, value} -> %{"Key" => key, "Value" => value} end)

    name = "/#{opts.env}/encryption-keys/#{key.id}"

    ExAws.SecretsManager.create_secret(%{
      "ClientRequestToken" => Ecto.UUID.generate(),
      "Tags" => tags,
      "Name" => name,
      "SecretString" => key.key
    })
  end
end
