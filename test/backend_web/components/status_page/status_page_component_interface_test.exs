defmodule BackendWeb.Components.StatusPage.StatusPageComponentInterfaceTest do
  use ExUnit.Case, async: true

  alias BackendWeb.Components.StatusPage.StatusPageComponentInterface
  alias Backend.Projections.Dbpa.StatusPage.ComponentChange
  alias Backend.Projections.Dbpa.StatusPage.StatusPageComponent
  alias Backend.Projections.Dbpa.StatusPage.StatusPageSubscription

  setup do
    status_page_id = "11yVP08lW36YDBPXDpzGsWk"
    component_id = "11yVOzRLMTG2Ig9BdUlntxi"
    subscription_id = "11yVP08lW0Qv91beddpVWdB"

    existing_subscription = %StatusPageSubscription{
      id: subscription_id,
      status_page_id: status_page_id,
      component_id: component_id
    }

    recent_change_id = Domain.Id.new()

    component_with_subscription = %StatusPageComponent{
      id: component_id,
      name: "testsignal",
      status_page_id: status_page_id,
      recent_change_id: recent_change_id,
    }

    component = %StatusPageComponent{
      id: Domain.Id.new(),
      name: "testsignal-new-component",
      status_page_id: Domain.Id.new(),
      recent_change_id: Domain.Id.new(),
    }

    component_change = %ComponentChange{
      id: recent_change_id,
      status_page_id: status_page_id,
      status: "operational",
      state: :up,
      instance: "us-east-1",
      changed_at: NaiveDateTime.utc_now()
    }

    %{
      subscriptions: [existing_subscription],
      components: [component_with_subscription, component],
      component_changes: [component_change]
    }
  end

  describe "page_component_subscriptions/3" do
    test "maps existing subscription id to corresponding component, otherwise nil", %{
      subscriptions: subscriptions,
      component_changes: component_changes,
      components: components
    } do
      assert [
               %{
                 name: "testsignal-new-component",
                 status_page_component_id: _,
                 status_page_id: _,
                 status_page_subscription_id: nil
               },
               %{
                name: "us-east-1 - testsignal",
                status_page_component_id: "11yVOzRLMTG2Ig9BdUlntxi",
                status_page_id: "11yVP08lW36YDBPXDpzGsWk",
                status_page_subscription_id: "11yVP08lW0Qv91beddpVWdB"
                }
             ] =
               StatusPageComponentInterface.page_component_subscriptions(
                 subscriptions,
                 components,
                 component_changes
               )
               |> Enum.sort(&(&1.name <= &2.name))
    end
  end

  describe "page_components_with_status/3" do
    test "marries existing status page component change state with corresponding status page component name, assigns unknown state for unassociated component change",
         %{
           components: components,
           component_changes: component_changes,
           subscriptions: subscriptions
         } do
      assert StatusPageComponentInterface.page_components_with_status(
               components,
               component_changes,
               subscriptions
             )
             |> Enum.sort(&(&1.name <= &2.name)) ==
               [
                %{
                  name: "testsignal-new-component",
                  status_page_component_id: Enum.reduce(components, nil, fn component, _ ->
                      if component.name == "testsignal-new-component" do
                        component.id
                      end
                    end),
                  state: :unknown,
                  enabled: false
                },
                %{name: "us-east-1 - testsignal", status_page_component_id: "11yVOzRLMTG2Ig9BdUlntxi", state: :up, enabled: true}
               ]
    end
  end

  describe "any_component_with_subscription?/2" do
    test "returns true when a list of page components has at least 1 associated status page subscription",
         %{components: components, subscriptions: subscriptions} do
      assert StatusPageComponentInterface.any_component_with_subscription?(
               components,
               subscriptions
             ) == true
    end
  end
end
