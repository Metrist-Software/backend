defmodule BackendWeb.Components.ListGroupSelectTest do
  use ExUnit.Case, async: true
  alias BackendWeb.Components.ListGroupSelect

  describe "filter_groups/2" do
    @data [
      %{
        id: "group1",
        label: "Group1",
        children: [
          %{
            id: "child1",
            label: "Child1"
          },
          %{
            id: "child2",
            label: "Child2"
          },
          %{
            id: "child3",
            label: "Child3"
          }
        ]
      },
      %{
        id: "group1",
        label: "Group2",
        children: []
      }
    ]

    test "filters monitors" do
      assert ListGroupSelect.filter_groups(@data, "child1") == [
               %{children: [%{id: "child1", label: "Child1"}], id: "group1", label: "Group1"}
             ]
    end

    test "filters group" do
      assert ListGroupSelect.filter_groups(@data, "group1") == [%{children: [], id: "group1", label: "Group1"}]
    end
  end
end
