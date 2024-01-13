defmodule Backend.Auth.Actor do
  @moduledoc """
  A module describing standard metadata for actors, entities (people, programs) that
  performed some action. We send actor information along as standard metadata to
  Commanded.

  Note that on round-trip through the database, all the keys will be read back as strings.
  We use atoms on creation only because it is a tiny bit cleaner.
  """

  def user(id, account_id), do: %{kind: :user, id: id, account_id: account_id}

  def api_token(account_id), do: %{kind: :api_token, account_id: account_id}

  def slack(user_id, account_id), do: %{kind: :slack, user_id: user_id, account_id: account_id}

  def datadog(user_id, account_id), do: %{kind: :datadog, user_id: user_id, account_id: account_id}

  def anonymous, do: %{kind: :anonymous}

  def metrist_api_token, do: %{kind: :admin, method: :api_token}

  def local_copy, do: %{kind: :admin, method: :local_copy}

  def backend_code, do: %{kind: :admin, method: :from_code}

  def db_setup, do: %{kind: :admin, method: :db_setup}

  def metrist_mix do
    {:ok, host} = :inet.gethostname()
    host = List.to_string(host)
    user = System.get_env("USER")
    %{kind: :admin, method: :mix_task, hostname: host, user: user}
  end
end
