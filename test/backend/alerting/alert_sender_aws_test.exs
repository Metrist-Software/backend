defmodule Backend.Alerting.AlertSenderAwsTest do
  use ExUnit.Case, async: true

  alias Backend.Alerting.AlertSenderAws
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail

  describe "AlertSenderAws tests" do
    test "to_pascal_case" do
      map = %{
        "string" => "a",
        :atom => "b",
        "split_string" => 1,
        :split_atom => 2,
        :list => [
          %{nested_map_key: "a"}
        ],
        :date_time => ~N[1970-01-01 00:00:00Z],
        :struct => %CheckDetail{check_id: "a", instance: "a", average: 123.0}
      }

      converted = AlertSenderAws.to_pascal_case(map)

      assert converted == %{
               "String" => "a",
               "Atom" => "b",
               "SplitString" => 1,
               "SplitAtom" => 2,
               "List" => [
                 %{"NestedMapKey" => "a"}
               ],
               "DateTime" => ~N[1970-01-01 00:00:00Z],
               "Struct" => %{
                 "CheckId" => "a",
                 "Instance" => "a",
                 "Average" => 123.0,
                 "CreatedAt" => nil,
                 "Current" => nil,
                 "LastChecked" => nil,
                 "Message" => nil,
                 "Name" => nil,
                 "State" => nil
               }
             }
    end
  end
end
