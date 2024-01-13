defmodule Backend.DbpaRepo.Migrations.AddDisplayNameToSubscriptions do
  use Ecto.Migration
  alias Ecto.Migration.Runner

  def change do
    alter table (:subscriptions) do
      add :display_name, :string
    end

    # Default this to whatever is in the identity column.
    execute(&execute_up/0, &execute_down/0)
  end

  defp execute_up, do: repo().query!("update \"#{Runner.prefix()}\".subscriptions set display_name=identity where display_name IS NULL")
  defp execute_down, do: repo().query!("")
end
