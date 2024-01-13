defmodule Backend.Repo.Migrations.AddApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens, primary_key: false) do
      add :api_token, :string, primary_key: true
      add :account_id, :string

      timestamps()
    end
  end
end
