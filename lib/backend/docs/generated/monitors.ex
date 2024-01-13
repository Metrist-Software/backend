defmodule Backend.Docs.Generated.Monitors do
  def all() do
    [
      "asana",
      "atlassianbitbucket",
      "authorizenet",
      "authzero",
      "avalara",
      "awscloudfront",
      "awscloudwatch",
      "awsecs",
      "awseks",
      "awselb",
      "awsiam",
      "awslambda",
      "awsrds",
      "awsrdspersistent",
      "awsroute53",
      "awssecretsmanager",
      "azuread",
      "azureaks",
      "azureappservice",
      "azureblob",
      "azurecdn",
      "azuredb",
      "azuredevops",
      "azuredevopsartifacts",
      "azuredevopsboards",
      "azuredevopspipelines",
      "azuredevopstestplans",
      "azurefncs",
      "azuremonitor",
      "azuresql",
      "azurevm",
      "bambora",
      "braintree",
      "circleci",
      "cloudflare",
      "cognito",
      "datadog",
      "discord",
      "easypost",
      "ec2",
      "eclipsefoundationservices",
      "envoy",
      "fastly",
      "freshbooks",
      "gcal",
      "gcpappengine",
      "gcpcloudstorage",
      "gcpcomputeengine",
      "github",
      "gitpod",
      "gke",
      "gmaps",
      "googledrive",
      "heroku",
      "hotjar",
      "hubspot",
      "humi",
      "jira",
      "kinesis",
      "launchpad",
      "lightspeed",
      "lightstep",
      "linode",
      "logrocket",
      "mavencentral",
      "moneris",
      "neon",
      "netlify",
      "newrelic",
      "nobl9",
      "npm",
      "nuget",
      "okta",
      "opsgenie",
      "pagerduty",
      "pubnub",
      "rubygemsorg",
      "s3",
      "sendgrid",
      "sentry",
      "ses",
      "slack",
      "snowflake",
      "sqs",
      "strava",
      "stripe",
      "taxjar",
      "testsignal",
      "trello",
      "twiliovid",
      "zendesk",
      "zoom"
    ]
  end

  @monitor_groups %{
    "netlify" => ["saas"],
    "easypost" => ["api"],
    "cloudflare" => ["infrastructure"],
    "braintree" => ["api"],
    "newrelic" => ["saas"],
    "kinesis" => ["aws"],
    "bambora" => ["api"],
    "azuredevopsartifacts" => ["azure"],
    "authzero" => ["saas"],
    "mavencentral" => ["saas"],
    "fastly" => ["api"],
    "ec2" => ["aws"],
    "azurecdn" => ["azure"],
    "gcal" => ["saas"],
    "ses" => ["aws"],
    "cognito" => ["aws"],
    "zoom" => ["saas"],
    "awssecretsmanager" => ["aws"],
    "eclipsefoundationservices" => ["saas"],
    "awscloudwatch" => ["aws"],
    "moneris" => ["api"],
    "twiliovid" => ["saas"],
    "s3" => ["aws"],
    "rubygemsorg" => ["saas"],
    "hotjar" => ["saas"],
    "circleci" => ["saas"],
    "discord" => ["saas"],
    "sqs" => ["aws"],
    "taxjar" => ["saas"],
    "pubnub" => ["api"],
    "azureappservice" => ["azure"],
    "gcpcloudstorage" => ["gcp"],
    "azuredb" => ["azure"],
    "zendesk" => ["saas"],
    "datadog" => ["saas"],
    "snowflake" => ["infrastructure"],
    "azuremonitor" => ["azure"],
    "neon" => ["infrastructure"],
    "linode" => ["saas"],
    "awsecs" => ["aws"],
    "awsroute53" => ["aws"],
    "azureblob" => ["azure"],
    "humi" => ["saas"],
    "azuresql" => ["azure"],
    "stripe" => ["api"],
    "heroku" => ["infrastructure"],
    "nuget" => ["saas"],
    "azurevm" => ["azure"],
    "azuredevopspipelines" => ["azure"],
    "freshbooks" => ["saas"],
    "awsrds" => ["aws"],
    "azuredevopsboards" => ["azure"],
    "logrocket" => ["saas"],
    "azuredevopstestplans" => ["azure"],
    "azuread" => ["azure"],
    "asana" => ["saas"],
    "gmaps" => ["saas"],
    "awsrdspersistent" => ["aws"],
    "awsiam" => ["aws"],
    "awslambda" => ["aws"],
    "opsgenie" => ["saas"],
    "azurefncs" => ["azure"],
    "hubspot" => ["api"],
    "okta" => ["saas"],
    "pagerduty" => ["saas"],
    "authorizenet" => ["saas"],
    "sentry" => ["saas"],
    "launchpad" => ["saas"],
    "jira" => ["saas"],
    "gitpod" => ["saas"],
    "lightspeed" => ["saas"],
    "gke" => ["gcp"],
    "awselb" => ["aws"],
    "azuredevops" => ["azure"],
    "atlassianbitbucket" => ["saas"],
    "trello" => ["saas"],
    "testsignal" => ["other"],
    "envoy" => ["saas"],
    "gcpappengine" => ["gcp"],
    "github" => ["api"],
    "avalara" => ["api"],
    "googledrive" => ["saas"],
    "npm" => ["saas"],
    "nobl9" => ["saas"],
    "awseks" => ["aws"],
    "azureaks" => ["azure"],
    "sendgrid" => ["api"],
    "gcpcomputeengine" => ["gcp"],
    "slack" => ["saas"],
    "strava" => ["saas"],
    "awscloudfront" => ["aws"],
    "lightstep" => ["saas"]
  }
  def monitor_groups(logical_name) when is_map_key(@monitor_groups, logical_name) do
    @monitor_groups[logical_name]
  end

  def monitor_groups(_) do
    []
  end

  def monitors_for_group("api") do
    [
      "avalara",
      "bambora",
      "braintree",
      "easypost",
      "fastly",
      "github",
      "hubspot",
      "moneris",
      "pubnub",
      "sendgrid",
      "stripe"
    ]
  end

  def monitors_for_group("aws") do
    [
      "awscloudfront",
      "awscloudwatch",
      "awsecs",
      "awseks",
      "awselb",
      "awsiam",
      "awslambda",
      "awsrds",
      "awsrdspersistent",
      "awsroute53",
      "awssecretsmanager",
      "cognito",
      "ec2",
      "kinesis",
      "s3",
      "ses",
      "sqs"
    ]
  end

  def monitors_for_group("azure") do
    [
      "azuread",
      "azureaks",
      "azureappservice",
      "azureblob",
      "azurecdn",
      "azuredb",
      "azuredevops",
      "azuredevopsartifacts",
      "azuredevopsboards",
      "azuredevopspipelines",
      "azuredevopstestplans",
      "azurefncs",
      "azuremonitor",
      "azuresql",
      "azurevm"
    ]
  end

  def monitors_for_group("gcp") do
    ["gcpappengine", "gcpcloudstorage", "gcpcomputeengine", "gke"]
  end

  def monitors_for_group("infrastructure") do
    ["cloudflare", "heroku", "neon", "snowflake"]
  end

  def monitors_for_group("other") do
    ["testsignal"]
  end

  def monitors_for_group("saas") do
    [
      "asana",
      "atlassianbitbucket",
      "authorizenet",
      "authzero",
      "circleci",
      "datadog",
      "discord",
      "eclipsefoundationservices",
      "envoy",
      "freshbooks",
      "gcal",
      "gitpod",
      "gmaps",
      "googledrive",
      "hotjar",
      "humi",
      "jira",
      "launchpad",
      "lightspeed",
      "lightstep",
      "linode",
      "logrocket",
      "mavencentral",
      "netlify",
      "newrelic",
      "nobl9",
      "npm",
      "nuget",
      "okta",
      "opsgenie",
      "pagerduty",
      "rubygemsorg",
      "sentry",
      "slack",
      "strava",
      "taxjar",
      "trello",
      "twiliovid",
      "zendesk",
      "zoom"
    ]
  end

  def monitors_for_group(_) do
    []
  end

  def name("asana") do
    "Asana"
  end

  def name("atlassianbitbucket") do
    "Atlassian Bitbucket "
  end

  def name("authorizenet") do
    "Authorize.net"
  end

  def name("authzero") do
    "Auth0"
  end

  def name("avalara") do
    "Avalara"
  end

  def name("awscloudfront") do
    "AWS CloudFront"
  end

  def name("awscloudwatch") do
    "AWS CloudWatch"
  end

  def name("awsecs") do
    "AWS Elastic Container Service — Fargate"
  end

  def name("awseks") do
    "AWS EKS"
  end

  def name("awselb") do
    "AWS Elastic Load Balancing"
  end

  def name("awsiam") do
    "AWS Identity and Access Management"
  end

  def name("awslambda") do
    "AWS Lambda"
  end

  def name("awsrds") do
    "AWS RDS (MySQL)"
  end

  def name("awsrdspersistent") do
    "AWS RDS Instance"
  end

  def name("awsroute53") do
    "AWS Route53"
  end

  def name("awssecretsmanager") do
    "AWS Secrets Manager"
  end

  def name("azuread") do
    "Azure Active Directory"
  end

  def name("azureaks") do
    "Azure Kubernetes Service"
  end

  def name("azureappservice") do
    "Azure App Service"
  end

  def name("azureblob") do
    "Azure Blob Storage"
  end

  def name("azurecdn") do
    "Azure CDN"
  end

  def name("azuredb") do
    "Azure Cosmos DB"
  end

  def name("azuredevops") do
    "Azure DevOps"
  end

  def name("azuredevopsartifacts") do
    "Azure DevOps Artifacts"
  end

  def name("azuredevopsboards") do
    "Azure DevOps Boards"
  end

  def name("azuredevopspipelines") do
    "Azure DevOps Pipelines"
  end

  def name("azuredevopstestplans") do
    "Azure DevOps Test Plans"
  end

  def name("azurefncs") do
    "Azure Functions"
  end

  def name("azuremonitor") do
    "Azure Monitor"
  end

  def name("azuresql") do
    "Azure SQL"
  end

  def name("azurevm") do
    "Azure VM"
  end

  def name("bambora") do
    "Bambora"
  end

  def name("braintree") do
    "Braintree"
  end

  def name("circleci") do
    "CircleCI"
  end

  def name("cloudflare") do
    "Cloudflare"
  end

  def name("cognito") do
    "AWS Cognito"
  end

  def name("datadog") do
    "Datadog"
  end

  def name("discord") do
    "Discord"
  end

  def name("easypost") do
    "EasyPost"
  end

  def name("ec2") do
    "AWS EC2"
  end

  def name("eclipsefoundationservices") do
    "Eclipse Foundation Services "
  end

  def name("envoy") do
    "Envoy"
  end

  def name("fastly") do
    "Fastly"
  end

  def name("freshbooks") do
    "Freshbooks"
  end

  def name("gcal") do
    "Google Calendar"
  end

  def name("gcpappengine") do
    "GCP App Engine"
  end

  def name("gcpcloudstorage") do
    "GCP Cloud Storage"
  end

  def name("gcpcomputeengine") do
    "GCP Compute Engine"
  end

  def name("github") do
    "GitHub"
  end

  def name("gitpod") do
    "Gitpod"
  end

  def name("gke") do
    "GCP GKE"
  end

  def name("gmaps") do
    "Google Maps"
  end

  def name("googledrive") do
    "Google Drive"
  end

  def name("heroku") do
    "Heroku"
  end

  def name("hotjar") do
    "Hotjar"
  end

  def name("hubspot") do
    "HubSpot"
  end

  def name("humi") do
    "Humi"
  end

  def name("jira") do
    "Jira"
  end

  def name("kinesis") do
    "AWS Kinesis"
  end

  def name("launchpad") do
    "LaunchPad"
  end

  def name("lightspeed") do
    "Lightspeed"
  end

  def name("lightstep") do
    "Lightstep"
  end

  def name("linode") do
    "Linode"
  end

  def name("logrocket") do
    "LogRocket"
  end

  def name("mavencentral") do
    "Maven Central"
  end

  def name("moneris") do
    "Moneris"
  end

  def name("neon") do
    "Neon"
  end

  def name("netlify") do
    "Netlify"
  end

  def name("newrelic") do
    "New Relic"
  end

  def name("nobl9") do
    "Nobl9"
  end

  def name("npm") do
    "NPM"
  end

  def name("nuget") do
    "NuGet"
  end

  def name("okta") do
    "Okta"
  end

  def name("opsgenie") do
    "Opsgenie"
  end

  def name("pagerduty") do
    "PagerDuty"
  end

  def name("pubnub") do
    "PubNub"
  end

  def name("rubygemsorg") do
    "Ruby Gems"
  end

  def name("s3") do
    "AWS S3"
  end

  def name("sendgrid") do
    "SendGrid"
  end

  def name("sentry") do
    "Sentry"
  end

  def name("ses") do
    "AWS SES"
  end

  def name("slack") do
    "Slack"
  end

  def name("snowflake") do
    "Snowflake"
  end

  def name("sqs") do
    "AWS SQS"
  end

  def name("strava") do
    "Strava"
  end

  def name("stripe") do
    "Stripe"
  end

  def name("taxjar") do
    "Taxjar"
  end

  def name("testsignal") do
    "Test Signal"
  end

  def name("trello") do
    "Trello"
  end

  def name("twiliovid") do
    "Twilio Video"
  end

  def name("zendesk") do
    "Zendesk"
  end

  def name("zoom") do
    "Zoom"
  end

  def name(monitor_id) do
    monitor_id
  end

  def description("asana") do
    "Monitor the observability of [Asana's API](https://developers.asana.com/docs)."
  end

  def description("atlassianbitbucket") do
    "Monitor the status page for Atlassian Bitbucket ."
  end

  def description("authorizenet") do
    "Monitor the status page for Authorize.net."
  end

  def description("authzero") do
    "Tests Auth0 to validate that access tokens and branding can be retrieved."
  end

  def description("avalara") do
    "Tests Avalara to validate that it is up and running."
  end

  def description("awscloudfront") do
    "Monitor the observability of a specific [AWS Cloudfront distribution](https://aws.amazon.com/cloudfront/)."
  end

  def description("awscloudwatch") do
    "Monitor the observability of a [AWS CloudWatch services](https://aws.amazon.com/cloudwatch/)."
  end

  def description("awsecs") do
    "Monitor the observability of a [AWS ECS services](https://aws.amazon.com/ecs/)."
  end

  def description("awseks") do
    "Monitor the observability of [AWS Elastic Kubernetes Service](https://aws.amazon.com/eks/)."
  end

  def description("awselb") do
    "Monitor the observability of [AWS ELB service](https://aws.amazon.com/elasticloadbalancing/)."
  end

  def description("awsiam") do
    "Monitor the observability of [AWS Identity and Access Management service](https://aws.amazon.com/iam/)."
  end

  def description("awslambda") do
    "Monitor the observability of [AWS Lambda](https://aws.amazon.com/lambda/)."
  end

  def description("awsrds") do
    "Monitor the observability of [AWS RDS service](https://aws.amazon.com/rds/)."
  end

  def description("awsrdspersistent") do
    "Monitor the observability of specific [AWS RDS Instance](https://aws.amazon.com/rds/)."
  end

  def description("awsroute53") do
    "Monitor the observability of [AWS Route53 service](https://aws.amazon.com/route53/)."
  end

  def description("awssecretsmanager") do
    "Monitor the availability of [AWS Secrets Manager](https://aws.amazon.com/secretsmanager/)."
  end

  def description("azuread") do
    "Monitor the observability of [Azure Active Directory](https://azure.microsoft.com/products/active-directory)."
  end

  def description("azureaks") do
    "Monitor the observability of [Azure Kubernetes Service](https://learn.microsoft.com/azure/aks/)."
  end

  def description("azureappservice") do
    "Monitor the observability of [Azure App Service](https://azure.microsoft.com/products/app-service/)."
  end

  def description("azureblob") do
    "Tests the Azure Blob Storage service to validate that blobs can be added, deleted, and retrieved, and that containers and storage accounts can be created."
  end

  def description("azurecdn") do
    "Monitor the observability of [Azure Content Delivery Network](https://azure.microsoft.com/products/cdn/)."
  end

  def description("azuredb") do
    "Monitor the observability of [Azure Cosmos Managed Databases](https://azure.microsoft.com/solutions/databases/)."
  end

  def description("azuredevops") do
    "Monitor the observability of [Azure DevOps service](https://azure.microsoft.com/products/devops/)."
  end

  def description("azuredevopsartifacts") do
    "Monitor the observability of [Azure DevOps Artifacts](https://azure.microsoft.com/products/devops/artifacts/)."
  end

  def description("azuredevopsboards") do
    "Monitor the observability of specific [Azure DevOps Board](https://azure.microsoft.com/products/devops/boards/)."
  end

  def description("azuredevopspipelines") do
    "Monitor the observability of [Azure DevOps Pipeslines service](https://azure.microsoft.com/products/devops/pipelines/)."
  end

  def description("azuredevopstestplans") do
    "Monitor the observability of [Azure DevOps Test Plans service](https://azure.microsoft.com/products/devops/test-plans/)."
  end

  def description("azurefncs") do
    "Monitor the observability of [Azure Functions service](https://azure.microsoft.com/products/functions/)."
  end

  def description("azuremonitor") do
    "Monitor the observability of [Azure Monitor service](https://azure.microsoft.com/products/monitor/)."
  end

  def description("azuresql") do
    "Monitor the observability of [Azure SQL database service](https://azure.microsoft.com/products/azure-sql)."
  end

  def description("azurevm") do
    "Monitor the observability of [Azure Virtual Machine service](https://azure.microsoft.com/products/virtual-machines/)."
  end

  def description("bambora") do
    "Tests Bambora to validate that purchases, refunds, and voids work with a test credit card."
  end

  def description("braintree") do
    "Tests Braintree to validate that sandbox transactions can be submitted."
  end

  def description("circleci") do
    "Tests CircleCI to validate that Docker and machine workflows can be run and that pipelines can be started."
  end

  def description("cloudflare") do
    "Tests Cloudflare to validate that the CDN is active, that DNS entries can be looked up, and that it can be pinged."
  end

  def description("cognito") do
    "Monitor the observability of the [AWS Cognito Identity Provider](https://aws.amazon.com/cognito/)."
  end

  def description("datadog") do
    "Tests Datadog to validate that events can be submitted and retrieved."
  end

  def description("discord") do
    "Monitor the status page for Discord."
  end

  def description("easypost") do
    "Tests EasyPost to validate that addresses can be retrieved in the test and prod environments and that addresses can be verified in the prod environment."
  end

  def description("ec2") do
    "Monitor the observability of the [AWS EC2 service](https://aws.amazon.com/ec2/)."
  end

  def description("eclipsefoundationservices") do
    "Monitor the status page for Eclipse Foundation Services ."
  end

  def description("envoy") do
    "Monitor the observability of [Envoy API](https://api.envoy.com/)."
  end

  def description("fastly") do
    "Tests Fastly to validate that non-cached and cached files can be retrieved and that caches can be purged."
  end

  def description("freshbooks") do
    "Monitor the status page for Freshbooks."
  end

  def description("gcal") do
    "Tests Google Calendar to validate that events can be created, retrieved, and deleted."
  end

  def description("gcpappengine") do
    "Tests Google App Engine to validate that autoscaling, pinging an app, deployments, and migrating traffic are operational."
  end

  def description("gcpcloudstorage") do
    "Tests the GCP Cloud Storage service to validate that buckets can be created and deleted and that items can be uploaded, retrieved, and deleted."
  end

  def description("gcpcomputeengine") do
    "Tests Google Compute Engine to validate that instances can be created, described, and deleted."
  end

  def description("github") do
    "Tests GitHub to validate that code can be pushed and pulled and that remote branches can be removed."
  end

  def description("gitpod") do
    "Monitor the status page for Gitpod."
  end

  def description("gke") do
    "Tests the GCP GKE service to validate that deployments can be created and removed."
  end

  def description("gmaps") do
    "Tests Google Maps to validate that directions and static images can be retrieved and that geocoding from a physical address works as expected."
  end

  def description("googledrive") do
    "Monitor the observability of [Google Drive API](https://developers.google.com/drive/api/)."
  end

  def description("heroku") do
    "Tests Heroku to validate that applications can be pinged, release webhooks are sent, and configurations can be updated."
  end

  def description("hotjar") do
    "Monitor the status page for Hotjar."
  end

  def description("hubspot") do
    "Tests HubSpot to validate that contacts can be retrieved."
  end

  def description("humi") do
    "Monitor the status page for Humi."
  end

  def description("jira") do
    "Tests Jira to validate that issues can be created and deleted."
  end

  def description("kinesis") do
    "Monitor the observability of [Amazon Kinesis](https://aws.amazon.com/kinesis/)."
  end

  def description("launchpad") do
    "Monitor the status page for LaunchPad."
  end

  def description("lightspeed") do
    "Monitor the status page for Lightspeed."
  end

  def description("lightstep") do
    "Monitor the status page for Lightstep."
  end

  def description("linode") do
    "Monitor the status page for Linode."
  end

  def description("logrocket") do
    "Monitor the status page for LogRocket."
  end

  def description("mavencentral") do
    "Monitor the status page for Maven Central."
  end

  def description("moneris") do
    "Tests Moneris to validate that purchases and refunds work with a test credit card."
  end

  def description("neon") do
    "Neon monitor (neon.tech)"
  end

  def description("netlify") do
    "Monitor the status page for Netlify."
  end

  def description("newrelic") do
    "Monitor the functionality of New Relic's web UI."
  end

  def description("nobl9") do
    "Monitor the status page for Nobl9."
  end

  def description("npm") do
    "Tests NPM to validate that packages can be downloaded and have their metadata retrieved."
  end

  def description("nuget") do
    "Tests NuGet to validate that packages can be downloaded and have their versions listed."
  end

  def description("okta") do
    "Monitor the functionality of Okta"
  end

  def description("opsgenie") do
    "Monitor the status page for Opsgenie."
  end

  def description("pagerduty") do
    "Tests PagerDuty to validate that events can be submitted, that incidents can be created, retrieved, and resolved, and that webhooks are sent."
  end

  def description("pubnub") do
    "Tests PubNub to validate that channels can be subscribed to and that messages can be sent and received."
  end

  def description("rubygemsorg") do
    "Monitor the status page for Ruby Gems."
  end

  def description("s3") do
    "Monitor the observability of [AWS Simple Storage Service (S3)](https://aws.amazon.com/s3/)."
  end

  def description("sendgrid") do
    "Tests SendGrid to validate that emails can be sent."
  end

  def description("sentry") do
    "Tests Sentry to validate events can be captured and that issues can be created, resolved, and deleted."
  end

  def description("ses") do
    "Monitor the observability of [AWS Simple Email Service](https://aws.amazon.com/ses/)."
  end

  def description("slack") do
    "Tests Slack to validate that messages can be sent."
  end

  def description("snowflake") do
    "Tests Snowflake to validate that databases, tables, and data can be created and deleted."
  end

  def description("sqs") do
    "Monitor the observability of [AWS Simple Queue Service](https://aws.amazon.com/sqs/)."
  end

  def description("strava") do
    "Monitor the status page for Strava."
  end

  def description("stripe") do
    "Tests Stripe to validate that intents can be created and confirmed and that methods can be created."
  end

  def description("taxjar") do
    "Monitor the status page for Taxjar."
  end

  def description("testsignal") do
    "  This monitor just sends a test signal through the system so we can verify that things are correctly working. Two checks generate random numbers from a Poisson and Normal distribution; the third always returns zero so we can measure monitor invocation overhead."
  end

  def description("trello") do
    "Tests Trello to validate that cards can be created and deleted."
  end

  def description("twiliovid") do
    "Tests Twilio Video to validate that rooms can be joined."
  end

  def description("zendesk") do
    "Tests Zendesk to validate that users can be retrieved and that tickets can be created, soft deleted, and permanently deleted."
  end

  def description("zoom") do
    "Tests Zooms API and the ability to join rooms."
  end

  def description(_) do
    ""
  end

  def status_page("asana") do
    nil
  end

  def status_page("atlassianbitbucket") do
    "https://bitbucket.status.atlassian.com/"
  end

  def status_page("authorizenet") do
    "https://status.authorize.net/"
  end

  def status_page("authzero") do
    "https://status.auth0.com"
  end

  def status_page("avalara") do
    "https://status.avalara.com/"
  end

  def status_page("awscloudfront") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awscloudwatch") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awsecs") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awseks") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awselb") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awsiam") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awslambda") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awsrds") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awsrdspersistent") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awsroute53") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("awssecretsmanager") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("azuread") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azureaks") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azureappservice") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azureblob") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azurecdn") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azuredb") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azuredevops") do
    "https://status.dev.azure.com/"
  end

  def status_page("azuredevopsartifacts") do
    "https://status.dev.azure.com/"
  end

  def status_page("azuredevopsboards") do
    "https://status.dev.azure.com/"
  end

  def status_page("azuredevopspipelines") do
    "https://status.dev.azure.com/"
  end

  def status_page("azuredevopstestplans") do
    "https://status.dev.azure.com/"
  end

  def status_page("azurefncs") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azuremonitor") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azuresql") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("azurevm") do
    "https://status.azure.com/en-us/status"
  end

  def status_page("bambora") do
    "https://status.na.bambora.com/"
  end

  def status_page("braintree") do
    nil
  end

  def status_page("circleci") do
    "https://status.circleci.com/"
  end

  def status_page("cloudflare") do
    "https://www.cloudflarestatus.com/"
  end

  def status_page("cognito") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("datadog") do
    "https://status.datadoghq.com/"
  end

  def status_page("discord") do
    "https://discordstatus.com/"
  end

  def status_page("easypost") do
    "https://easypost.statuspage.io/"
  end

  def status_page("ec2") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("eclipsefoundationservices") do
    "https://www.eclipsestatus.io/"
  end

  def status_page("envoy") do
    "https://status.envoy.com/"
  end

  def status_page("fastly") do
    nil
  end

  def status_page("freshbooks") do
    "https://status.freshbooks.com/"
  end

  def status_page("gcal") do
    nil
  end

  def status_page("gcpappengine") do
    "https://status.cloud.google.com/"
  end

  def status_page("gcpcloudstorage") do
    "https://status.cloud.google.com/"
  end

  def status_page("gcpcomputeengine") do
    "https://status.cloud.google.com/"
  end

  def status_page("github") do
    "https://www.githubstatus.com/"
  end

  def status_page("gitpod") do
    "https://www.gitpodstatus.com/"
  end

  def status_page("gke") do
    "https://status.cloud.google.com/"
  end

  def status_page("gmaps") do
    nil
  end

  def status_page("googledrive") do
    nil
  end

  def status_page("heroku") do
    "https://status.hubspot.com/"
  end

  def status_page("hotjar") do
    "https://status.hotjar.com/"
  end

  def status_page("hubspot") do
    "https://status.hubspot.com/"
  end

  def status_page("humi") do
    "https://status.humi.ca/"
  end

  def status_page("jira") do
    "https://jira-software.status.atlassian.com/"
  end

  def status_page("kinesis") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("launchpad") do
    "https://launchpad.statuspage.io/"
  end

  def status_page("lightspeed") do
    "https://status.lightspeedhq.com/"
  end

  def status_page("lightstep") do
    "https://status.lightstep.com/"
  end

  def status_page("linode") do
    "https://status.linode.com/"
  end

  def status_page("logrocket") do
    "https://status.logrocket.com/"
  end

  def status_page("mavencentral") do
    "https://status.maven.org/"
  end

  def status_page("moneris") do
    nil
  end

  def status_page("neon") do
    nil
  end

  def status_page("netlify") do
    "https://www.netlifystatus.com/"
  end

  def status_page("newrelic") do
    "https://newrelic.statuspage.io/"
  end

  def status_page("nobl9") do
    "https://nobl9.statuspage.io/"
  end

  def status_page("npm") do
    "https://status.npmjs.org/"
  end

  def status_page("nuget") do
    nil
  end

  def status_page("okta") do
    "https://status.okta.com/"
  end

  def status_page("opsgenie") do
    "https://opsgenie.status.atlassian.com/"
  end

  def status_page("pagerduty") do
    "https://status.pagerduty.com/"
  end

  def status_page("pubnub") do
    "https://status.pubnub.com/"
  end

  def status_page("rubygemsorg") do
    "https://status.rubygems.org/"
  end

  def status_page("s3") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("sendgrid") do
    "https://status.sendgrid.com/"
  end

  def status_page("sentry") do
    "https://status.sentry.io/"
  end

  def status_page("ses") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("slack") do
    nil
  end

  def status_page("snowflake") do
    nil
  end

  def status_page("sqs") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("strava") do
    "https://status.strava.com/"
  end

  def status_page("stripe") do
    "https://health.aws.amazon.com/health/status"
  end

  def status_page("taxjar") do
    "https://status.taxjar.com/"
  end

  def status_page("testsignal") do
    nil
  end

  def status_page("trello") do
    "https://trello.status.atlassian.com/"
  end

  def status_page("twiliovid") do
    "https://status.twilio.com/"
  end

  def status_page("zendesk") do
    nil
  end

  def status_page("zoom") do
    "https://status.zoom.us/"
  end

  def status_page(_) do
    nil
  end
end