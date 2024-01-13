defmodule BackendWeb.Components.StatusPage.StatusPageComponentInterface do
  @moduledoc """
  A utility module for managing the UI around page component subscription
  configurations.
  """

  alias Backend.Projections.Dbpa.StatusPage.StatusPageComponent
  alias Backend.Projections.Dbpa.StatusPage.ComponentChange
  alias Backend.Projections.Dbpa.StatusPage.StatusPageSubscription

  @type component_interface :: %{
          required(:status_page_subscription_id) => String.t() | nil,
          required(:status_page_component_id) => String.t(),
          required(:status_page_id) => String.t(),
          required(:name) => String.t()
        }

  @spec page_component_subscriptions(
          list(StatusPageSubscription.t()),
          list(StatusPageComponent.t()),
          list(ComponentChange.t())
        ) :: list(component_interface)

  @doc """
  Returns a list of maps containing status_page_component and status_page_subscription
  ids with status_page_subscription_id set to nil if no subscription exists for a page
  component along with the component name
  """
  def page_component_subscriptions(status_page_subscriptions, status_page_components, component_changes) do
    status_page_components
    |> Enum.map(fn component ->
      %{
        name: get_component_name_with_instance(component_changes, component),
        status_page_id: component.status_page_id,
        status_page_component_id: component.id,
        status_page_subscription_id:
          find_matching_subscription_id(status_page_subscriptions, component)
      }
    end)
    |> Enum.sort_by(&(&1.name))
  end

  @spec page_components_with_status(
          list(StatusPageComponent.t()),
          list(ComponentChange.t()),
          list(StatusPageSubscription.t())
        ) :: list(component_interface)
  @doc """
  Returns a list of maps containing status_page_component names with corresponding
  statuses taken from the associated stuats_page_component_changes
  """
  def page_components_with_status(
        status_page_components,
        component_changes,
        status_page_subscriptions
      ) do
    status_page_components
    |> Enum.map(fn component ->
      %{
        name: get_component_name_with_instance(component_changes, component),
        status_page_component_id: component.id,
        state: assign_matching_component_change_state(component_changes, component),
        enabled: subscription_exists?(status_page_subscriptions, component)
      }
    end)
    |> Enum.sort_by(&(&1.name))
  end

  @spec any_component_with_subscription?(
          list(StatusPageComponent.t()),
          list(StatusPageSubscription.t())
        ) :: boolean()
  def any_component_with_subscription?(page_components, page_subscriptions) do
    page_components
    |> Enum.any?(fn component -> subscription_exists?(page_subscriptions, component) end)
  end

  defp assign_matching_component_change_state(component_changes, %StatusPageComponent{
         recent_change_id: change_id
       }) do
    Enum.find(component_changes, &(&1.id == change_id))
    |> case do
      nil -> :unknown
      component_change -> Map.get(component_change, :state, :unknown)
    end
  end

  defp get_component_name_with_instance(component_changes, %StatusPageComponent{
         recent_change_id: change_id,
         name: name
       }) do
    Enum.find(component_changes, &(&1.id == change_id))
    |> case do
      nil -> name
      component_change ->
        if not is_nil(component_change.instance) do
          "#{component_change.instance} - #{name}"
        else
          name
        end
    end
  end

  defp subscription_exists?(status_page_subscriptions, %StatusPageComponent{} = page_component),
    do: not is_nil(find_matching_subscription_id(status_page_subscriptions, page_component))

  defp find_matching_subscription_id(status_page_subscriptions, %StatusPageComponent{id: id}) do
    Enum.find(status_page_subscriptions, fn subscription ->
      subscription.component_id == id
    end)
    |> case do
      nil -> nil
      subscription -> Map.get(subscription, :id, nil)
    end
  end
end
