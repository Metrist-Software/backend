defmodule Backend.StatusPages.AwsStatusPageScraper do
  alias Backend.StatusPages.Scraper

  @behaviour Scraper
  require Logger

  @aws_service_map %{
    "ses" => "ses",
    "cognito" => "cognito",
    "ec2" => "ec2",
    "kinesisanalytics" => "kinesis",
    "kinesis" => "kinesis",
    "firehose" => "kinesis",
    "acuity" => "kinesis",
    "lambda" => "awslambda",
    "s3" => "s3",
    "sqs" => "sqs",
    "cloudfront" => "awscloudfront",
    "cloudwatch" => "awscloudwatch",
    "ecs" => "awsecs",
    "rds" => "awsrds",
    "route53" => "awsroute53",
    "elb" => "awselb",
    "eks" => "awseks",
    "iam" => "awsiam"
  }

  @aws_interested_regions [
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
    "ca-central-1",
    :global
  ]

  @rss_prefix "https://status.aws.amazon.com/rss/"

  @impl Scraper
  def name(), do: "AWS Status Page Scraper"

  @impl Scraper
  def scrape() do
    [:elixir_feed_parser]
    |> Enum.map(&Application.ensure_all_started/1)

    { :ok,
      for {awskey, monitor_logical_name} <- @aws_service_map do
        get_results_for_aws_key(awskey, monitor_logical_name)
      end
      |> Enum.group_by(fn {service, _observations} -> service end, fn {_service, observations} -> observations end)
      |> Enum.map(fn {key, list} -> {key, List.flatten(list)} end)
    }
  end

  defp get_results_for_aws_key(awskey, monitor_logical_name) do
    observations =
      for region <- @aws_interested_regions do
        rss_url = case region do
          :global -> "#{@rss_prefix}#{awskey}.rss"
          _ -> "#{@rss_prefix}#{awskey}-#{region}.rss"
        end
        case HTTPoison.get(rss_url) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> { :ok, process_rss_body(body, region, monitor_logical_name) }
          {:ok, %HTTPoison.Response{status_code: 404}} -> { :not_available, {region, monitor_logical_name} }
          {:ok, %HTTPoison.Response{status_code: status_code}} ->
            Logger.error("Couldn't retrieve #{rss_url} for #{inspect {region, monitor_logical_name}}. Status code was #{status_code}")
            {:error, "Non-200/404 status"}
          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("Couldn't retrieve #{rss_url} for #{inspect {region, monitor_logical_name}} because of #{reason}")
            {:error, reason}
        end
      end
      |> List.flatten()
      |> Enum.reject(fn {status, _} -> status == :error || status == :not_available end)
      |> Enum.map(fn {:ok, {_, component, region, status}} ->
        state = Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(status)

        %Domain.StatusPage.Commands.Observation{
          changed_at: NaiveDateTime.utc_now(),
          component: component,
          instance: region,
          status: status,
          state: state
        }
      end)
    {monitor_logical_name, observations}
  end

  def process_rss_body(nil, _region, _monitor_logical_name), do: nil
  def process_rss_body(body, region, monitor_logical_name) do
    { :ok, feed } =
      body
      |> fix_timezone()
      |> ElixirFeedParser.parse()

    component = feed.title
    case Enum.count(feed.entries) do
      0 -> {monitor_logical_name, component, region, "Good"}
      _ ->
        [top_entry | _tail] = feed.entries
        status = get_entry_status(top_entry)
        state = Backend.Projections.Dbpa.StatusPage.status_page_status_to_snapshot_state(status)
        %Domain.StatusPage.Commands.Observation{
          changed_at: NaiveDateTime.utc_now(),
          component: component,
          instance: region,
          status: status,
          state: state
        }
        {monitor_logical_name, component, region, status}
    end
  end

  def service_map, do: @aws_service_map

  # AWS puts "PST/PDT" in their pubDate which doesn't match any IANA timezone and can't be resolved by tz/tzdata
  # Switch it to GMT-8/GMT-7 dependent on PST/PDT
  defp fix_timezone(body) do
    body
    |> String.replace("PST", "GMT-8")
    |> String.replace("PDT", "GMT-7")
  end

  defp get_entry_status(entry) do
    # handle inconsistency in AWS RSS feeds. Sometimes there's a Service is operating normally message at the top of the stack
    # other times they just put [RESOLVED] somewhere in the message. Sometimes there's 1 space after the colon then [RESOLVED]
    # sometimes there are 2....
    # Last but not least sometimes they just don't put any resolution message of any kind... look at how old the message is in
    # that case.... See https://status.aws.amazon.com/rss/cloudwatch-us-west-1.rss for an example
    cut_off = NaiveDateTime.utc_now() |> Timex.shift(days: -1)
    naive_update_date = DateTime.to_naive(entry.updated)
    case NaiveDateTime.compare(naive_update_date, cut_off) == :lt do
      true -> "Good"
      false ->
        case String.contains?(entry.title, "[RESOLVED]") do
          true -> "Good"
          false -> do_get_entry_status_from_message(entry)
        end
    end
  end

  defp do_get_entry_status_from_message(%{title: << "Service is operating normally:", _rest::binary>>}), do: "Good"
  defp do_get_entry_status_from_message(%{title: << "Informational message:", _rest::binary>>}), do: "Information"
  defp do_get_entry_status_from_message(%{title: << "Service degradation:", _rest::binary>>}), do: "Degraded"
  defp do_get_entry_status_from_message(%{title: << "Service disruption:", _rest::binary>>}), do: "Disruption"
  # anything else is unexpected. In that case simply return the "Good" state
  defp do_get_entry_status_from_message(_), do: "Good"
end
