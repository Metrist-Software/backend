defmodule Backend.StatusPage.EventHandlers do
  use Commanded.Event.Handler,
    application: Backend.App,
    name: __MODULE__,
    subscription_opts: [
      checkpoint_threshold: 100,
      checkpoint_after: 5_000
    ]

  alias Backend.Projections.Account
  alias Backend.Projections.Dbpa.StatusPage.StatusPageSubscription
  alias Domain.StatusPage.Commands
  alias Backend.PubSub

  def handle(e = %Domain.StatusPage.Events.Created{}, _metadata) do
    PubSub.broadcast_status_page_created!(e.id)
  end

  def handle(
        e = %Domain.StatusPage.Events.ComponentRemoved{},
        %{event_id: causation_id, correlation_id: correlation_id}
      ) do
    Account.list_accounts()
    |> Enum.map(fn account ->
      build_remove_subscription_cmd(account.id, e.id, Domain.StatusPage.component_id_of(e))
    end)
    |> Enum.reject(&(&1 == nil))
    |> Enum.each(fn cmd ->
      Backend.App.dispatch(cmd,
        causation_id: causation_id,
        correlation_id: correlation_id)
    end)

    :ok
  end

  def handle(
      e = %Domain.Account.Events.MonitorAdded{},
      %{event_id: causation_id, correlation_id: correlation_id}
    ) do

      if Backend.StatusPage.Helpers.url_for(e.logical_name) do
        status_page = Backend.Projections.Dbpa.StatusPage.status_page_by_name(Domain.Helpers.shared_account_id(), e.logical_name)
        components =
          case status_page do
            nil -> []
            _ -> Backend.Projections.Dbpa.StatusPage.StatusPageComponent.components(Domain.Helpers.shared_account_id(), status_page.id)
          end

        components
        |> Enum.map(fn component ->
          %Commands.AddSubscription{
            id: status_page.id,
            component_id: component.id,
            account_id: e.id
          }
        end)
        |> Enum.each(fn cmd ->
              Backend.App.dispatch(cmd,
                causation_id: causation_id,
                correlation_id: correlation_id
              )
            end)
      end
    :ok
  end

  def handle(
      e = %Domain.Account.Events.MonitorRemoved{},
      %{event_id: causation_id, correlation_id: correlation_id}
    ) do
      status_page = Backend.Projections.Dbpa.StatusPage.status_page_by_name(Domain.Helpers.shared_account_id(), e.logical_name)
      existing_subscriptions =
        case status_page do
          nil -> []
          _ -> Backend.Projections.Dbpa.StatusPage.StatusPageSubscription.subscriptions(e.id, status_page.id)
        end
      existing_subscriptions
      |> Enum.map(fn subscription ->
        %Commands.RemoveSubscription{
          id: status_page.id,
          component_id: subscription.component_id,
          subscription_id: subscription.id,
          account_id: e.id
        }
      end)
      |> Enum.each(fn cmd ->
            Backend.App.dispatch(cmd,
              causation_id: causation_id,
              correlation_id: correlation_id
            )
          end)
    :ok
  end

  defp build_remove_subscription_cmd(_, _, nil), do: nil

  defp build_remove_subscription_cmd(account_id, status_page_id, page_component_id) do
    case fetch_subscription(account_id, status_page_id, page_component_id) do
      nil ->
        nil

      subscription ->
        %Commands.RemoveSubscription{
          id: status_page_id,
          component_id: page_component_id,
          subscription_id: subscription.id,
          account_id: account_id
        }
    end
  end

  defp fetch_subscription(account_id, status_page_id, page_component_id) do
    case StatusPageSubscription.subscriptions_by_filter(account_id,
           status_page_id: status_page_id,
           component_id: page_component_id
         ) do
      [] -> nil
      [subscription | _rest] -> subscription
    end
  end
end
