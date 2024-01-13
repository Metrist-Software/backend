defmodule Backend.RealTimeAnalytics.StatusPageCache do
  @moduledoc """
  Caches status_page, status_page_component and status_page_component_changes to be used by
  analysis processes. Status page scraping is done from only one account (the old "SHARED"
  account) and the data is reused/shared.
  """
  use GenServer

  @status_page_owner_account_id "SHARED"

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def initialize() do
    Logger.info("StatusPageCache: Starting initialize")
    GenServer.call(__MODULE__, :initialize, 10000)
    Logger.info("StatusPageCache: Initialize complete")
  end

  def status_page(status_page_name) do
    key = {:status_pages, status_page_name}

    case :ets.lookup(__MODULE__, key) do
      [{^key, status_page}] -> status_page
      [] -> nil
    end
  end

  def component(component_id) do
    key = {:status_page_component, component_id}

    case :ets.lookup(__MODULE__, key) do
      [{^key, component}] ->
        component

      [] ->
        # This can happen when a new a component is added and is non existent when the loader started
        if component =
             Backend.Projections.Dbpa.StatusPage.StatusPageComponent.component_by_id(
               @status_page_owner_account_id,
               component_id
             ) do
          [change] =
            Backend.Projections.Dbpa.StatusPage.component_changes_from_change_ids(@status_page_owner_account_id, [
              component.recent_change_id
            ])

          :ets.insert(__MODULE__, {{:status_page_component, component.id}, component})
          :ets.insert(__MODULE__, {{:status_page_component_change, component.id}, change})
          component
        else
          Logger.warning("Asked to find Status Page Component with id #{component_id} but it doesn't exist")
          nil
        end
    end
  end

  def invalidate_component(component_id) do
    :ets.delete(__MODULE__, {:status_page_component, component_id})
  end

  def component_change!(component_id) do
    key = {:status_page_component_change, component_id}

    case :ets.lookup(__MODULE__, key) do
      [{^key, change}] -> change
      [] -> throw("Recent change for component id #{component_id} not found")
    end
  end

  def subscriptions(account_id, status_page_id) do
    key = {:status_page_subscriptions, account_id, status_page_id}

    case :ets.lookup(__MODULE__, key) do
      [{^key, subscriptions}] -> subscriptions
      [] -> []
    end
  end

  def component_changes(component_ids) do
    Enum.map(component_ids, &component/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn component -> {component.id, component_change!(component.id)} end)
  end

  def customer_account_subscriptions(account_ids) do
    Task.async_stream(account_ids, fn id ->
        subscriptions =
          Backend.Projections.Dbpa.StatusPage.StatusPageSubscription.subscriptions(id)

        {id, subscriptions}
      end,
      max_concurrency: 10
    )
    |> Enum.into(%{}, fn {:ok, value} -> value end)
  end

  def init(_) do
    :ets.new(__MODULE__, [:named_table, :public])
    {:ok, nil}
  end

  def handle_call(:initialize, _from, state) do
    Logger.info("StatusPageCache: Loading data")
    load_data()
    {:reply, :ok, state}
  end

  # Use PubSub broadcast to sync this data across all nodes and keep it up to date
  def handle_info(%{event: %Domain.StatusPage.Events.ComponentStatusChanged{} = e}, state) do
    :ets.insert(__MODULE__,
    {
      {:status_page_component_change, e.component_id},
      Backend.Projections.Dbpa.StatusPage.ComponentChange.from_event(e)
    })
    {:noreply, state}
  end
  def handle_info(%{event: %Domain.StatusPage.Events.SubscriptionAdded{} = e}, state) do
    subscription =
      Backend.Projections.Dbpa.StatusPage.StatusPageSubscription.from_event(e)

    key = {:status_page_subscriptions, e.account_id, e.id}

    existing_subscriptions = subscriptions(e.account_id, e.id)

    :ets.insert(
      __MODULE__,
      {key, [ subscription | existing_subscriptions ]}
    )
    {:noreply, state}
  end
  def handle_info(%{event: %Domain.StatusPage.Events.SubscriptionRemoved{} = e}, state) do
    key = {:status_page_subscriptions, e.account_id, e.id}

    updated_subscriptions =
      subscriptions(e.account_id, e.id)
      |> Enum.reject(fn sub -> sub.id == e.subscription_id end)

    :ets.insert(
      __MODULE__,
      {key, updated_subscriptions}
    )
    {:noreply, state}
  end
  def handle_info(%{event: %Domain.StatusPage.Events.ComponentAdded{} = e}, state) do
    component_id = Domain.StatusPage.component_id_of(e)
    invalidate_component(component_id)
    {:noreply, state}
  end
  def handle_info({:status_page_created, status_page_id}, state) do
    subscribe_to_status_page_component_changes(status_page_id)
    {:noreply, state}
  end
  def handle_info(e, state) do
    Logger.debug("Unhandled Status Page event in StatusPageCache #{inspect e}")
    {:noreply, state}
  end

  defp load_data() do
    account_ids = Backend.Projections.list_accounts() |> Enum.map(& &1.id)
    account_subscription = customer_account_subscriptions(account_ids)

    components =
      Backend.Projections.Dbpa.StatusPage.StatusPageComponent.all_components_for_account(
        @status_page_owner_account_id
      )

    # This could end up being a problem once we have more than 32,768 components
    # Probably want to project the recent changes to a separate projection table
    recent_changes =
      Backend.Projections.Dbpa.StatusPage.component_changes_from_change_ids(
        @status_page_owner_account_id,
        Enum.map(components, & &1.recent_change_id)
      )

    for status_page <-
          Backend.Projections.Dbpa.StatusPage.status_pages() do
        subscribe_to_status_page_component_changes(status_page.id)
        :ets.insert(__MODULE__, {{:status_pages, status_page.name}, status_page})
    end

    for component <- components do
      :ets.insert(__MODULE__, {{:status_page_component, component.id}, component})
    end

    for change <- recent_changes do
      component_for_change =
        components
        |> Enum.find(fn comp -> comp.recent_change_id == change.id end)
      :ets.insert(__MODULE__, {{:status_page_component_change, component_for_change.id}, change})
    end

    for {account_id, subscription} <- account_subscription,
        {status_page_id, subscriptions} <-
          Enum.group_by(subscription, fn sub -> sub.status_page_id end) do
      :ets.insert(
        __MODULE__,
        {{:status_page_subscriptions, account_id, status_page_id}, subscriptions}
      )
    end

    Backend.PubSub.subscribe_status_page_created()
  end

  defp subscribe_to_status_page_component_changes(status_page_id) do
    topic = %Domain.StatusPage.Events.SubscriptionAdded{id: status_page_id}

    Backend.PubSub.unsubscribe_to_topic_of(topic)
    Backend.PubSub.subscribe_to_topic_of(topic)
  end
end
