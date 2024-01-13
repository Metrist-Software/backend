defmodule Backend.Notifications.ToPascalCaseHelperTest do
  use ExUnit.Case

  alias Backend.Notifications.WebhookHandler
  alias Backend.Projections.Dbpa.Snapshot.CheckDetail

  describe "to_pascal_case" do

    test "does not alter naive datetime" do
      naive_date_time = ~N[2000-01-01 23:00:07]
      assert WebhookHandler.to_pascal_case(naive_date_time) == naive_date_time
    end

    test "converts list elements" do
      list_of_things = [1, "list", "of", "things", ~N[2000-01-01 23:00:07]]
      assert WebhookHandler.to_pascal_case(list_of_things) == list_of_things
    end

    test "converts the elements of maps" do
      map = %{
        "string" => "a",
        :atom => "b",
        "split_string" => 1,
        :split_atom => 2,
        :list => [
          %{nested_map_key: "a"}
        ],
        :naive_date_time => ~N[1970-01-01 00:00:00Z],
        :struct => %CheckDetail{check_id: "a", instance: "a", average: 123.0}
      }

      assert WebhookHandler.to_pascal_case(map) == %{
        "String" => "a",
        "Atom" => "b",
        "SplitString" => 1,
        "SplitAtom" => 2,
        "List" => [
          %{"NestedMapKey" => "a"}
        ],
        "NaiveDateTime" => ~N[1970-01-01 00:00:00Z],
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

    test "converts a struct to a map, then converts it" do
      struct = %CheckDetail{
        check_id: "a",
        instance: "a",
        average: 123.0
      }

      assert WebhookHandler.to_pascal_case(struct) == %{
        "Average" => 123.0,
        "CheckId" => "a",
        "CreatedAt" => nil,
        "Current" => nil,
        "Instance" => "a",
        "LastChecked" => nil,
        "Message" => nil,
        "Name" => nil,
        "State" => nil
      }
    end

    test "otherwise, returns the value unchanged" do
      any_other_type = "Like a string or number."
      assert WebhookHandler.to_pascal_case(any_other_type) == any_other_type
      any_other_type = 1_000
      assert WebhookHandler.to_pascal_case(any_other_type) == any_other_type
    end

  end

end
