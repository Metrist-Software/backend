defmodule Backend.Twitter.Client do
  @moduledoc """
  The bits of code that actually talk to twitter.
  """
  require Logger

  @endpoint "https://api.twitter.com"

  @doc """
  Count the number of tweets for the hashtag since the given DateTime.
  """
  @spec count_tweets(String.t(), NaiveDateTime.t()) :: non_neg_integer()
  def count_tweets(hashtag, since) do
    headers = [authorization: "Bearer #{bearer_token()}"]
    query = [
      # Twitter is _very_ picky about the format. No microseconds, and the timezone is mandatory.
      start_time: NaiveDateTime.to_iso8601(%{since | microsecond: {0, 0}}) <> "Z",
      query: "##{hashtag}"

    ]
    url = "#{@endpoint}/2/tweets/counts/recent?#{URI.encode_query(query)}"
    case HTTPoison.get(url, headers) do
       {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, response} = Jason.decode(body)
        response["meta"]["total_tweet_count"]
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Cannot fetch counts from Twitter, reason: #{inspect reason}")
        0
    end
  end

  # See Application.configure_twitter()
  defp bearer_token, do: Application.get_env(:backend, :twitter_bearer_token)
end
