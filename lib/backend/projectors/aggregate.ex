defmodule Backend.Projectors.Aggregate do
  use Commanded.Projections.Ecto,
    application: Backend.App,
    name: __MODULE__,
    repo: Backend.Repo,
    start_from: :current

  @moduledoc """
  Projection reponsible for handling events and
  projecting appropriately shapped data to aggregate tables
  """

  alias Domain.User, as: User
  alias Domain.Account, as: Account
  alias Backend.Projections
  require Logger

  @impl true
  def error({:error, _error}, event, _failure_context) do
    Logger.error("ERROR: could not project event in aggregate: #{inspect event}")
    :skip
  end

  project(e = %User.Events.LoggedIn{}, _metadata, fn multi ->
    # We need the is_internal to filter out internal accounts
    user = Projections.get_user(e.id)
    # Possible that the user has no account or they are so new that we can't read them yet, treat that as not internal
    account = if user && user.account_id do
      Projections.get_account(user.account_id)
    else
      %Account{ is_internal: false }
    end

    Ecto.Multi.insert(multi, :aggregate_projector, %Projections.Aggregate.WebLoginAggregate{
      id: Domain.Id.new(),
      time: e.timestamp,
      user_id: e.id,
      is_internal: account.is_internal
    },
    on_conflict: :raise)
  end)

  project(e = %Account.Events.SlackSlashCommandAdded{}, _metadata, fn multi ->
    account = Projections.get_account(e.id)
    case account do
      nil ->
        # Can occur if we are replaying old events where the id isn't the account id
        Logger.warn("Can't emit slack aggregate as it is the old event format without the account id as the id")
      _ ->
        Ecto.Multi.insert(multi, :aggregate_projector, %Projections.Aggregate.AppUseAggregate{
          id: Domain.Id.new(),
          time: NaiveDateTime.utc_now(),
          user_id: Map.get(e.data, :UserId),
          is_internal: account.is_internal,
          app_type: Atom.to_string(:slack)
        },
        on_conflict: :nothing)
    end
  end)


  project(e = %Account.Events.MicrosoftTeamsCommandAdded{}, _metadata, fn multi ->
    account = Projections.get_account(e.id)
    case account do
      nil ->
        # Can occur if we are replaying old events where the id isn't the account id
        Logger.warn("Can't emit teams aggregate as it is the old event format without the account id as the id")
      _ ->
        Ecto.Multi.insert(multi, :aggregate_projector, %Projections.Aggregate.AppUseAggregate{
          id: Domain.Id.new(),
          time: NaiveDateTime.utc_now(),
          user_id: get_in(e.data, [:Data, :from, :id]),
          is_internal: account.is_internal,
          app_type: Atom.to_string(:teams)
        },
        on_conflict: :nothing)
    end
  end)




    project(e = %Account.Events.Created{}, _metadata, fn multi ->
      Ecto.Multi.insert(multi, :aggregate_projector, %Projections.Aggregate.NewSignupAggregate{
        id: e.id,
        time: NaiveDateTime.utc_now(),
      },
      on_conflict: :nothing)
    end)


end
