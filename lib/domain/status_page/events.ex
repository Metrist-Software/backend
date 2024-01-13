defmodule Domain.StatusPage.Events do
  use TypedStruct

  typedstruct module: Created, enforce: true do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :page, String.t()
  end

  typedstruct module: Removed, enforce: true do
    plugin(Backend.JsonUtils)
    field :id, String.t()
  end

  typedstruct module: ComponentStatusChanged, enforce: true do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :data_component_id, String.t(), enforce: false
    field :change_id, String.t()
    field :component_id, String.t(), enforce: false
    field :component, String.t()
    field :status, String.t()
    # Not enforced mostly for backwards compatability
    field :state, Backend.RealTimeAnalytics.Snapshotting.state(), enforce: false
    field :instance, String.t()
    field :changed_at, NaiveDateTime.t()
  end

  typedstruct module: ComponentAdded, enforce: true do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :data_component_id, String.t(), enforce: false
    field :instance, String.t(), enforce: false
    field :account_id, String.t()
    field :change_id, String.t()
    field :name, String.t()
    field :component_id, String.t(), enforce: false
  end

  typedstruct module: ComponentRemoved, enforce: true do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :data_component_id, String.t(), enforce: false
    field :instance, String.t(), enforce: false
    field :account_id, String.t()
    field :name, String.t()
    field :component_id, String.t(), enforce: false
  end

  typedstruct module: Reset, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
  end

  typedstruct module: SubscriptionAdded do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :subscription_id, String.t()
    field :component_id, String.t()
    field :account_id, String.t()
  end

  typedstruct module: SubscriptionRemoved do
    plugin(Backend.JsonUtils)
    field :id, String.t()
    field :subscription_id, String.t()
    field :component_id, String.t()
    field :account_id, String.t()
  end

  typedstruct module: ComponentChangeRemoved, enforce: true do
    plugin Backend.JsonUtils
    field :id, String.t()
    field :change_id, String.t()
  end
end
