defmodule SecretsManagerRepoTestHelper do
  @gke_key %{
    "ARN" =>
      "arn:aws:secretsmanager:us-east-1:123:secret:/dev1/encryption-keys/Secret",
    "CreatedDate" => 1_680_803_248.322,
    "LastAccessedDate" => 1_681_257_600.0,
    "LastChangedDate" => 1_680_803_248.36,
    "Name" => "/dev1/encryption-keys/Secret",
    "SecretVersionsToStages" => %{
      "ef8d8708-0edf-45ab-a8df-ec577f760e29" => ["AWSCURRENT"]
    },
    "Tags" => [
      %{"Key" => "key:owner_id", "Value" => "SHARED_gke"},
      %{"Key" => "key:owner_type", "Value" => "monitor"},
      %{"Key" => "key:is_default", "Value" => "true"},
      %{"Key" => "key:scheme", "Value" => "aes_256_cbc"},
      %{"Key" => "key:id", "Value" => "120A5zkXEFkdKsjIOOU6q0b"},
      %{"Key" => "env", "Value" => "dev1"}
    ]
  }

  def aws_list_secrets(filters) do
    # Horribly complex thing to pick apart, so we do string stuff instead to match
    # what was requested.
    filters_string = inspect(filters)

    cond do
      String.contains?(filters_string, "SHARED_gke") ->
        {:ok,
         %{
           "SecretList" => [@gke_key]
         }}

      String.contains?(filters_string, "bad_id") ->
        {:ok, %{"SecretList" => []}}

      String.contains?(filters_string, "multiple") ->
        {:ok,
         %{
           "SecretList" => [
             %{
               "ARN" => "some_arn1",
               "Tags" => [
                 %{"Key" => "key:owner_id", "Value" => "multiple"},
                 %{"Key" => "key:owner_type", "Value" => "account"},
                 %{"Key" => "key:is_default", "Value" => "false"}
               ]
             },
             %{
               "ARN" => "some_arn2",
               "Tags" => [
                 %{"Key" => "key:owner_id", "Value" => "multiple"},
                 %{"Key" => "key:owner_type", "Value" => "account"},
                 %{"Key" => "key:is_default", "Value" => "true"}
               ]
             },
             %{
               "ARN" => "some_arn3",
               "Tags" => [
                 %{"Key" => "key:owner_id", "Value" => "multiple"},
                 %{"Key" => "key:owner_type", "Value" => "account"},
                 %{"Key" => "key:is_default", "Value" => "true"}
               ]
             }
           ]
         }}

      true ->
        :error
    end
  end
end

defmodule Backend.Crypto.SecretsManagerRepoTest do
  use ExUnit.Case, async: true

  alias Backend.Crypto.SecretsManagerRepo, as: SMR

  test "Find secret works in the simple case" do
    {:ok, _arn, meta} = SMR.find_secret("monitor", "SHARED_gke", SecretsManagerRepoTestHelper)

    assert meta == %SMR.KeyMeta{
             id: "120A5zkXEFkdKsjIOOU6q0b",
             is_default: true,
             owner_id: "SHARED_gke",
             owner_type: "monitor",
             scheme: "aes_256_cbc",
             key: nil
           }
  end

  test "Not found returns correct result" do
    {:error, :not_found} = SMR.find_secret("monitor", "bad_id", SecretsManagerRepoTestHelper)
  end

  test "When multiple keys are returned, the default one is taken" do
    {:ok, arn, meta} = SMR.find_secret("account", "multiple", SecretsManagerRepoTestHelper)

    assert %SMR.KeyMeta{is_default: true} = meta

    # We take the first default key
    assert arn == "some_arn2"
  end
end
