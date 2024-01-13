defmodule Backend.Projections.MicrosoftTeamsCommand do
  use Ecto.Schema

  @primary_key {:id, :string, []}
  schema "microsoft_teams_commands" do
    field :data, :map

    timestamps()
  end
end
