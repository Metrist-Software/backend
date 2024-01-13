defmodule BackendWeb.HelpersTest do
  use ExUnit.Case, async: true

  describe "Formatting of telemetry values" do
    import BackendWeb.Helpers, only: [format_telemetry_value: 1, format_telemetry_value: 2]
    test "Seconds values are formatted as seconds above 5 seconds" do
      assert format_telemetry_value(5000) == "5000.00 ms"
      assert format_telemetry_value(5001) == "5.00 s"
    end

    test "Joiner is applied correctly" do
      assert format_telemetry_value(100, joiner: "") == "100.00ms"
      assert format_telemetry_value(100, joiner: "--") == "100.00--ms"
    end

    test "A nil value is returned as an ellipsis" do
      assert format_telemetry_value(nil) == "… ms"
    end
  end

  describe "Checking of user struct from session" do
    import BackendWeb.Helpers, only: [is_user_up_to_date?: 1]
    test "User that matches schema is up to date" do
      user =
        %Backend.Projections.User{
          account_id: "test",
          email: "test",
          hubspot_contact_id: "test",
          id: "test",
          inserted_at: NaiveDateTime.utc_now(),
          is_metrist_admin: false,
          is_read_only: true,
          last_login: NaiveDateTime.utc_now(),
          timezone: nil,
          uid: "test",
          updated_at: NaiveDateTime.utc_now()
        }
      assert is_user_up_to_date?(user) == true
    end

    test "User with one extra field is not up to date" do
      user =
        %{
          account_id: "test",
          email: "test",
          hubspot_contact_id: "test",
          id: "test",
          inserted_at: NaiveDateTime.utc_now(),
          is_metrist_admin: false,
          is_read_only: true,
          last_login: NaiveDateTime.utc_now(),
          timezone: nil,
          uid: "test",
          updated_at: NaiveDateTime.utc_now(),
          extra: "this_does_not_belong_in_the_schema"
        }
      assert is_user_up_to_date?(user) == false
    end

    test "User missing one field from schema is not up to date" do
      user =
        %{
          account_id: "test",
          email: "test",
          hubspot_contact_id: "test",
          id: "test",
          inserted_at: NaiveDateTime.utc_now(),
          is_read_only: true,
          last_login: NaiveDateTime.utc_now(),
          timezone: nil,
          uid: "test",
          updated_at: NaiveDateTime.utc_now()
        }
      assert is_user_up_to_date?(user) == false
    end

    test "User with same number of fields but different key name is not up to date" do
      user =
        %{
          account_id: "test",
          email: "test",
          hubspot_contact_id: "test",
          id: "test",
          inserted_at: NaiveDateTime.utc_now(),
          is_admin: false,
          is_read_only: true,
          last_login: NaiveDateTime.utc_now(),
          timezone: nil,
          uid: "test",
          updated_at: NaiveDateTime.utc_now()
        }
      assert is_user_up_to_date?(user) == false
    end

    test "User with no fields is not up to date" do
      assert is_user_up_to_date?(%{}) == false
    end

    test "User that is nil is up to date by default" do
      assert is_user_up_to_date?(nil) == true
    end
  end

  describe "format_with_tz/2" do
    import BackendWeb.Helpers, only: [format_with_tz: 2]
    test "nil timezone argument defaults to UTC" do
      ndt = ~N[2022-08-23 13:21:00.965549]
      assert format_with_tz(ndt, nil) == "23 Aug, 13:21:00 UTC"
    end

    test "UTC timezone argument still defaults to UTC" do
      ndt = ~N[2022-08-23 13:21:00.965549]
      assert format_with_tz(ndt, "UTC") == "23 Aug, 13:21:00 UTC"
      assert format_with_tz(ndt, "Etc/UTC") == "23 Aug, 13:21:00 UTC"
    end

    test "valid timezone argument displays proper formatted time" do
      ndt = ~N[2022-08-23 13:21:00.965549]
      assert format_with_tz(ndt, "US/Pacific") == "23 Aug, 06:21:00 PDT"
    end
  end

  describe "datetime_to_tz/2" do
    import BackendWeb.Helpers, only: [datetime_to_tz: 2]
    test "nil timezone argument defaults to UTC" do
      ndt = ~N[2022-08-23 13:21:00.965549]
      assert datetime_to_tz(ndt, nil) == ~U[2022-08-23 13:21:00.965549Z]
    end

    test "UTC timezone argument still defaults to UTC" do
      ndt = ~N[2022-08-23 13:21:00.965549]
      assert datetime_to_tz(ndt, "UTC") == ~U[2022-08-23 13:21:00.965549Z]
      assert datetime_to_tz(ndt, "Etc/UTC") == ~U[2022-08-23 13:21:00.965549Z]
    end

    test "valid timezone argument displays proper formatted time" do
      ndt = ~N[2022-08-23 13:21:00.965549]
      {:ok, converted_dt} = DateTime.new(NaiveDateTime.to_date(ndt), ~T[06:21:00.965549], "US/Pacific")
      assert datetime_to_tz(ndt, "US/Pacific") == converted_dt
    end
  end
end
