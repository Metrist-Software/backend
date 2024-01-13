defmodule Backend.Utils do

  @type retry_options::[max_attempts: pos_integer(), sleep_time: pos_integer(), success_check: (any() -> boolean())]

  @spec do_with_retries((pos_integer() -> any()), retry_options) :: {:error, :max_retries} | {:ok, any}
  def do_with_retries(action, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 10)
    sleep_time = Keyword.get(opts, :sleep_time, 1_000)

    success_check = Keyword.get(opts, :success_check, & !is_nil(&1))

    do_with_retries(action, success_check, 1, max_attempts, sleep_time)
  end

  defp do_with_retries(_action, _success_check, current_attempts, max_attempts, _sleep_time) when current_attempts > max_attempts, do: {:error, :max_retries}
  defp do_with_retries(action, success_check, current_attempts, max_attempts, sleep_time) do
    result = action.(current_attempts)

    if success_check.(result) do
      {:ok, result}
    else
      if sleep_time > 0, do: Process.sleep(sleep_time)

      do_with_retries(action, success_check, current_attempts + 1, max_attempts, sleep_time)
    end
  end
end
