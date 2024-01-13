defmodule BackendWeb.LandingPageSupportControllerTest do
  use ExUnit.Case, async: true

  test "Basic summarizing of snapshots" do
    snaps = [
      %{
        check_details: [
          %{
            check_id: "AutoScaleUp",
            instance: "gcp:us-west1",
            name: "AutoScaleUp",
            state: :up
          },
        ],
        last_checked: ~N[2022-06-06 17:48:12.099968],
        monitor_id: "gcpappengine",
        state: :up
      },
      %{
        check_details: [
        ],
        last_checked: ~N[2022-06-06 17:46:10.627640],
        monitor_id: "gcpcloudstorage",
        state: :down
      },
      %{
        check_details: [
        ],
        last_checked: ~N[2022-06-06 17:36:30.860113],
        monitor_id: "gcpcomputeengine",
        state: :degraded
      },
      %{
        check_details: [
        ],
        last_checked: ~N[2022-06-06 17:46:32.322231],
        monitor_id: "gke",
        state: :up
      }
    ]

    result = BackendWeb.LandingPageSupportController.snapshots_to_cloud_state_overview(snaps)
    assert result.last_checked == ~N[2022-06-06 17:48:12.099968]
    assert result.state == :down
    assert length(result.monitors) == 4
    assert hd(result.monitors) == %{
      check_details: [
        %{
          check_id: "AutoScaleUp",
          instance: "gcp:us-west1",
          name: "AutoScaleUp",
          state: :up
        }
      ],
      last_checked: ~N[2022-06-06 17:48:12.099968],
      monitor_logical_name: "gcpappengine",
      state: :up
    }
  end
end
