defmodule Backend.StatusPage.Helpers do
  @atlassian_status_page_observers [
    "trello",
    "cloudflare",
    "npm",
    "jira",
    "zoom",
    "github",
    "pubnub",
    "sentry",
    "avalara",
    "bambora",
    "datadog",
    "hubspot",
    "circleci",
    "easypost",
    "sendgrid",
    "pagerduty",
    "opsgenie",
    "launchpad",
    "lightspeed",
    "humi",
    "freshbooks",
    "nobl9",
    "lightstep",
    "gitpod",
    "logrocket",
    "eclipsefoundationservices",
    "mavencentral",
    "discord",
    "strava",
    "linode",
    "netlify",
    "rubygemsorg",
    "authorizenet",
    "hotjar",
    "taxjar",
    "atlassianbitbucket",
    "newrelic",
    "envoy"
  ]

  # display state timeline only if at least one status component is subscribed to
  @subscription_required_to_render [
    "cloudflare",
    "fastly"
  ]

  def requires_status_component_subscription?(monitor_logical_name) do
    Enum.member?(@subscription_required_to_render, monitor_logical_name)
  end


  def url_for(monitor_logical_name) do
    # try for an atlassian hit first
    # if that doesn't work look up the tags and look for azure/gcp/aws
    case url_for(monitor_logical_name, nil) do
      nil ->
        tag = get_aws_azure_or_gcp_tag_for_monitor(monitor_logical_name)
        url_for(monitor_logical_name, tag)
      url -> url
    end
  end

  # testsignal is used for our local testing
  def url_for("testsignal", _tag), do: "https://localhost/testsignalstatuspage"
  def url_for("testmonitor", _tag), do: "https://localhost/testmonitorstatuspage"
  def url_for(_monitor_logical_name, "aws"), do: "https://health.aws.amazon.com/health/status"
  def url_for(_monitor_logical_name, "azure"), do: "https://status.azure.com/en-us/status"
  def url_for(_monitor_logical_name, "gcp"), do: "https://status.cloud.google.com/"
  def url_for(monitor_logical_name, _tag) do
    atlassian_status_pages()
    |> Map.get(monitor_logical_name)
  end

  def atlassian_status_pages do
    Enum.map(@atlassian_status_page_observers, fn logical_name ->
      {logical_name, Backend.Docs.Generated.Monitors.status_page(logical_name)}
    end)
    |> Enum.reject(&(is_nil(elem(&1, 1))))
    |> Map.new()
  end

  defp get_aws_azure_or_gcp_tag_for_monitor(monitor_logical_name) do
    groups = Backend.Docs.Generated.Monitors.monitor_groups(monitor_logical_name)

    MapSet.new(groups)
    |> MapSet.intersection(MapSet.new(["aws", "azure", "gcp"]))
    |> MapSet.to_list()
    |> List.first()
  end
end
