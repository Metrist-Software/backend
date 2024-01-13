defmodule Backend.Projections.SlackWorkspace do
  use Ecto.Schema
  @primary_key {:id, :string, []}
  schema "slack_workspaces" do
    field :team_name, :string
    field :scope, {:array, :string}
    field :bot_user_id, :string
    field :access_token, :string

    belongs_to :account, Backend.Projections.Account, foreign_key: :account_id, references: :id, type: :string
  end

  import Ecto.Query
  alias Backend.Repo

  def get_slack_workspaces(account_id) do
    from(sw in __MODULE__, where: sw.account_id == ^account_id)
    |> Repo.all()
  end



  def has_slack_workspaces?(account_id) do
    from(sw in __MODULE__, where: sw.account_id == ^account_id)
    |> Repo.exists?()
  end

  def get_slack_workspace(workspace_id, preloads \\ []) do
    from(sw in __MODULE__, where: sw.id == ^workspace_id)
    |> preload(^preloads)
    |> Repo.one()
  end


  def has_slack_token?("") do
    false
  end

  def has_slack_token?(workspace_id) do
    from(sw in __MODULE__, where: sw.id == ^workspace_id)
    |> Repo.exists?()
  end

  def get_slack_token(nil) do
    nil
  end

  def get_slack_token(workspace_id) do
    from(sw in __MODULE__, where: sw.id == ^workspace_id, select: sw.access_token)
    |> Repo.one()
  end

end
