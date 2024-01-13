defmodule Support.CommandedHelpers do
  @doc """
  For testing projectors and event handlers, properly formed fake metadata. You
  can override what you want in the arguments.
  """
  def fake_metadata(opts \\ %{}) do
    %{
      :application => Backend.App,
      :causation_id => UUID.uuid1(),
      :correlation_id => UUID.uuid1(),
      :created_at => DateTime.utc_now(), # And not NaiveDateTime!
      :event_id => UUID.uuid1(),
      :event_number => 42,
      :handler_name => "TestHandler",
      :state => nil,
      :stream_id => "SHARED_testsignal",
      :stream_version => 123,
      "actor" => %{
        "kind" => "admin",
        "method" => "db_setup"
      }
    }
    |> Map.merge(opts)
  end
end
