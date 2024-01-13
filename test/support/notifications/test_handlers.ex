defmodule Test.Support.Notifications.TestHandlers do
  defmodule SuccessfulSingleResponse do
    def make_request(_, _), do: "this is a test"
    def get_response(_), do: {:ok, %{status_code: 200}}
  end

  defmodule ErrorSingleResponse do
    def make_request(_, _), do: "this is a test"
    def get_response(_), do: {:error, %{status_code: 200}}
  end

  defmodule SingleResponse do
    def make_request(_, _), do: "this is a test"
    def get_response(_), do: {:ok, %{status_code: 200}}
  end

  defmodule SuccessfulMultiResponse do
    def make_request(_, _), do: ["good", "good", "good"]
    def get_response(_), do: {:ok, %{status_code: 200}}
  end

  defmodule ErrorMultiResponse do
    def make_request(_, _), do: ["good", "bad", "good"]
    def get_response("good"), do: {:ok, %{status_code: 200}}
    def get_response("bad"), do: {:error, %{status_code: 200}}
  end

  defmodule NonStandardResponse do
    def make_request(_, _), do: "test"
    def get_response(_), do: {:ok, "Response"}
    def response_ok?({:ok, "Response"}), do: true
    def response_status_code({:ok, "Response"}), do: 201
  end
end
