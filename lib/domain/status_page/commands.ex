defmodule Domain.StatusPage.Commands do
  use TypedStruct

  typedstruct module: AddSubscription, enforce: true do
    use Domo
    field :id, String.t()
    field :component_id, String.t()
    field :account_id, String.t()
  end

  typedstruct module: Create, enforce: true do
    use Domo
    field :id, String.t()
    field :page, String.t()
  end

  # adding a data_component_id since the Atlassian status pages can be set up with
  # duplicate component (names) and this is causing "jitter noise" in the
  # projection data
  typedstruct module: Observation, enforce: true do
    use Domo
    field :data_component_id, String.t(), enforce: false
    field :component, String.t()
    field :status, String.t()
    field :state, Backend.RealTimeAnalytics.Snapshotting.state()
    field :instance, String.t() | nil | :global
    field :changed_at, NaiveDateTime.t()
  end

  typedstruct module: ProcessObservations, enforce: true do
    @moduledoc """
    This command is mostly geared at making life easy for callers. They may not
    have the status page id, so they can specify the page name instead. Either
    one must be set of course.
    """
    use Domo
    field :id, String.t(), enforce: false
    field :page, String.t(), enforce: false
    field :observations, [Observation.t()]
  end

  typedstruct module: RemoveComponent, enforce: true do
    use Domo
    field :id, String.t()
    field :component_name, String.t()
  end

  typedstruct module: Remove, enforce: true do
    @derive Jason.Encoder
    use Domo
    field :id, String.t()
  end

  typedstruct module: RemoveComponentChanges, enforce: true do
    use Domo
    field :id, String.t()
    field :change_ids, [String.t()]
  end

  typedstruct module: Print, enforce: true do
    use Domo
    field :id, String.t()
  end

  typedstruct module: Reset, enforce: true do
    use Domo
    field :id, String.t
  end

  typedstruct module: RemoveSubscription, enforce: true do
    use Domo
    field :id, String.t()
    field :account_id, String.t()
    field :component_id, String.t()
    field :subscription_id, String.t()
  end

  typedstruct module: SetSubscriptions, enforce: true do
    use Domo
    field :id, String.t()
    field :account_id, String.t()
    field :component_ids, [String.t()]
  end
end
