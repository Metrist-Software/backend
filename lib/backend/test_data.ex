defmodule Backend.TestData do
  @moduledoc """
  Test data for the monitoring report thing. The test
  data was copy/pasted from a production GraphQL response.
  """

  @awslambda "priv/testdata/awslambda.json"
  |> File.read!()
  |> Jason.decode!(keys: :atoms)

  @pagerduty "priv/testdata/pagerduty.json"
  |> File.read!()
  |> Jason.decode!(keys: :atoms)

  def get_report("awslambda") do
    @awslambda.data
  end
  def get_report("pagerduty") do
    @pagerduty.data
  end
  def get_report(mon) do
    raise "get report is not implemented for #{mon}!"
  end
end
