defmodule Backend.Projections.SlackSlashCommand do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "slack_slash_commands" do
    field :data, :map

    timestamps()
  end
end
