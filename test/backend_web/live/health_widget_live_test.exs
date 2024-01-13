defmodule BackendWeb.Live.HealthWidgetLiveTest do
  use ExUnit.Case, async: true
  alias BackendWeb.Datadog.HealthWidgetLive

  @recent_time_stamp_ms DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.to_unix(:millisecond)

  @sample_test %{
    "last_timestamp_fetched" => @recent_time_stamp_ms,
    "locations" => ["aws:us-west-1"],
    "name" => "[Zendesk] Transactional",
    "public_id" => "26f-x8i-pzm",
    "results" => [],
    "tags" => ["metrist-created"]
  }

  @single_step_result_sample %{
    "check_time" => 2,
    "result_id" => "4330154811795090846",
    "check_version" => 4,
    "status" => 1,
    "probe_dc" => "aws:us-west-1",
    "result" => %{
      "errorMessage" => "[{\"actual\":401,\"operator\":\"is\",\"target\":200,\"type\":\"statusCode\"},{\"actual\":\"application/json\",\"operator\":\"is\",\"property\":\"content-type\",\"target\":\"application/json; charset=utf-8\",\"type\":\"header\"}]",
      "passed" => true,
      "runType" => 3,
      "timings" => %{
        "firstByte" => 24.7,
        "tcp" => 21.8,
        "ssl" => 44.6,
        "dns" => 21.3,
        "download" => 0.6,
        "total" => 113
      },
      "tunnel" => false
    }
  }

  @multi_step_result_sample %{
    "check_time" => @recent_time_stamp_ms,
    "check_version" => 18,
    "probe_dc" => "aws:us-west-1",
    "result" => %{
      "duration" => 1327.1999999999998,
      "errorCount" => 0,
      "errorMessage" => nil,
      "passed" => true,
      "runType" => 0,
      "stepCountCompleted" => 3,
      "stepCountTotal" => 3,
      "timings" => nil,
      "tunnel" => false
    },
    "result_id" => "7776641514854022443",
    "status" => 0
  }


  describe "is_degraded?/1" do
    setup do
      sample_results = [
        %{
          "check_time" => @recent_time_stamp_ms,
          "check_version" => 18,
          "probe_dc" => "aws:us-west-1",
          "result" => %{
            "duration" => 1080.3,
            "errorCount" => 0,
            "errorMessage" => nil,
            "passed" => true,
            "runType" => 0,
            "stepCountCompleted" => 3,
            "stepCountTotal" => 3,
            "timings" => nil,
            "tunnel" => false
          },
          "result_id" => "4758305746162887148",
          "status" => 0
        },
        %{
          "check_time" => @recent_time_stamp_ms,
          "check_version" => 18,
          "probe_dc" => "aws:us-west-1",
          "result" => %{
            "duration" => 1019.8,
            "errorCount" => 0,
            "errorMessage" => nil,
            "passed" => true,
            "runType" => 0,
            "stepCountCompleted" => 3,
            "stepCountTotal" => 3,
            "timings" => nil,
            "tunnel" => false
          },
          "result_id" => "2585510265531644103",
          "status" => 0
        }
      ]

      the_test =
        @sample_test
        |> put_in(["results"],
          Enum.map(
            Enum.with_index(sample_results), fn {result, index} ->
            Map.put(result, "check_time", DateTime.to_unix(DateTime.utc_now(), :millisecond) + index)
          end))

      [the_test: the_test]
    end

    test "Most recent value above average will cause degraded", context do
      the_test = context.the_test
      new_result =
        List.last(Map.get(the_test, "results"))
        |> put_in(["check_time"], DateTime.to_unix(DateTime.utc_now(), :millisecond))
        |> put_in(["result", "duration"], 999999999)

      the_test =
        Map.put(the_test, "results", [ new_result | Map.get(the_test, "results") ])

      assert HealthWidgetLive.is_degraded?(the_test)
    end

    test "Will be degraded if even a single probe is degraded", context do
      the_test = context.the_test
      now = DateTime.to_unix(DateTime.utc_now(), :millisecond)
      new_results =
        [
        List.last(Map.get(the_test, "results"))
        |> put_in(["probe_dc"], "probe2")
        |> put_in(["check_time"], now)
        |> put_in(["result", "duration"], 999999999),
        List.last(Map.get(the_test, "results"))
        |> put_in(["probe_dc"], "probe2")
        |> put_in(["check_time"], now-1)
        |> put_in(["result", "duration"], 1)
        ]

      the_test =
        Map.put(the_test, "results", new_results ++ Map.get(the_test, "results"))

      assert HealthWidgetLive.is_degraded?(the_test)
    end

    test "Only a single value will return false" do
      the_test =
        @sample_test
        |> put_in(["results"], [@multi_step_result_sample])

      assert !HealthWidgetLive.is_degraded?(the_test)
    end
  end


  describe "is_issues?/1" do
    setup do
      [the_test: @sample_test, multi_step: @multi_step_result_sample, single_step: @single_step_result_sample]
    end

    test "A single probe failure with multiple probes will claim issues", context do
      the_test = context.the_test
      test_results = [
        put_in(context.multi_step, ["result", "passed"], false),
        context.multi_step,
        context.multi_step
        |> put_in(["probe_dc"], "other_probe")
      ]
      the_test = Map.put(the_test, "results", test_results)
      assert HealthWidgetLive.is_issues?(the_test)
    end

    test "!passed on one probe but passed on another will still result in issues", context do
      the_test = context.the_test
      test_results = [
        context.multi_step
        |> put_in(["result", "passed"], false),
        context.multi_step,
        context.multi_step
        |> put_in(["probe_dc"], "other_probe")
      ]
      the_test = Map.put(the_test, "results", test_results)
      assert HealthWidgetLive.is_issues?(the_test)
    end
  end

  describe "is_down?/1" do
    setup do
      [the_test: @sample_test, multi_step: @multi_step_result_sample, single_step: @single_step_result_sample]
    end

    test "All probes having !passed will result in down", context do
      the_test = context.the_test
      test_results = [
        context.multi_step
        |> put_in(["result", "passed"], false),
        context.multi_step
        |> put_in(["probe_dc"], "other_probe")
        |> put_in(["result", "passed"], false)
      ]
      the_test = Map.put(the_test, "results", test_results)
      assert HealthWidgetLive.is_down?(the_test)
    end
    test "Any probes having passed will not result in down", context do
      the_test = context.the_test
      test_results = [
        context.multi_step
        |> put_in(["result", "passed"], false),
        context.multi_step
        |> put_in(["probe_dc"], "other_probe")
      ]
      the_test = Map.put(the_test, "results", test_results)
      assert !HealthWidgetLive.is_down?(the_test)
    end
  end

  describe "get_state?/1" do
    test "Values outside of 7 day range won't affect state" do
      the_test = @sample_test

      new_result =
        @multi_step_result_sample
        |> put_in(["check_time"], 1)
        |> put_in(["result", "duration"], 1)

      the_test =
        the_test
        |> Map.put("results", [@multi_step_result_sample] ++ List.duplicate(new_result, 50))

      assert HealthWidgetLive.get_state(the_test) == :up
    end

    test "Having only results older than 7 days will still function and return :unknown" do
      the_test =
        @sample_test
        |> Map.put("results", [
          @multi_step_result_sample
          |> Map.put("check_time", 1)
        ])

      assert HealthWidgetLive.get_state(the_test) == :unknown
    end

    test "Get state when all data is older than 7 days returns unknown" do
      old_datetime =
        DateTime.utc_now()
        |> DateTime.add(-14, :day)
        |> DateTime.to_unix(:millisecond)

      updated_sample =
        @sample_test
        |> Map.put("results", [
          @multi_step_result_sample
          |> Map.put("check_time", old_datetime)
        ])

      assert HealthWidgetLive.get_state(updated_sample) == :unknown
    end

    test "No results will return :unknown" do
      assert HealthWidgetLive.get_state(@sample_test) == :unknown
    end
  end
end
